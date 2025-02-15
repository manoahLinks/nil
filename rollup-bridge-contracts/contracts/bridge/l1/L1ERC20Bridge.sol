// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IL1ERC20Bridge } from "./interfaces/IL1ERC20Bridge.sol";
import { IL2ERC20Bridge } from "../l2/interfaces/IL2ERC20Bridge.sol";
import { IL1BridgeRouter } from "./interfaces/IL1BridgeRouter.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { BridgeBase } from "../BridgeBase.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";

/// @title L1ERC20Bridge
/// @notice The `L1ERC20Bridge` contract for ERC20 gateways in L1.
contract L1ERC20Bridge is IL1ERC20Bridge, BridgeBase, IERC165 {
  using SafeTransferLib for ERC20;

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Mapping from l1 token address to l2 token address for ERC20 token.
  mapping(address => address) public tokenMapping;

  /// @dev The storage slots for future usage.
  uint256[50] private __gap;

  /*//////////////////////////////////////////////////////////////////////////
                             CONSTRUCTOR   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Constructor for `L1ERC20Bridge` implementation contract.
  constructor() BridgeBase() {
    _disableInitializers();
  }

  /// @notice Initialize the storage of L1ERC20Bridge.
  ///
  /// @dev The parameters `_nilERC20Bridge`, `_router` and `_messenger` are no longer used.
  ///
  /// @param _owner The owner of L1ERC20Bridge in layer-1.
  /// @param _counterPartyERC20Bridge The address of ERC20Bridge on nil-chain
  /// @param _messenger The address of NilMessenger in layer-1.
  function initialize(address _owner, address _counterPartyERC20Bridge, address _messenger) external initializer {
    BridgeBase._initialize(_owner, _counterPartyERC20Bridge, _messenger);
  }

  function setRouter(address _router) external onlyOwner {
    router = _router;
  }

  modifier onlyRouter() {
    require(msg.sender == router, "Caller is not the router");
    _;
  }

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL1ERC20Bridge
  function depositERC20(address _token, uint256 _amount, uint256 _gasLimit) external payable override {
    _deposit(_token, _msgSender(), _amount, new bytes(0), _gasLimit);
  }

  /// @inheritdoc IL1ERC20Bridge
  function depositERC20(address _token, address _to, uint256 _amount, uint256 _gasLimit) external payable override {
    _deposit(_token, _to, _amount, new bytes(0), _gasLimit);
  }

  /// @inheritdoc IL1ERC20Bridge
  function depositERC20AndCall(
    address _token,
    address _to,
    uint256 _amount,
    bytes memory _data,
    uint256 _gasLimit
  ) external payable override {
    _deposit(_token, _to, _amount, _data, _gasLimit);
  }

  /// @inheritdoc IL1ERC20Bridge
  function getL2ERC20Address(address _l1TokenAddress) external view override returns (address) {
    return tokenMapping[_l1TokenAddress];
  }

  /// @inheritdoc IL1ERC20Bridge
  function cancelDeposit(bytes32 messageHash) external payable override nonReentrant {
    address caller = _msgSender();

    // get DepositMessageDetails
    IL1BridgeMessenger.DepositMessage memory depositMessage = IL1BridgeMessenger(messenger).getDepositMessage(
      messageHash
    );

    if (caller != router && caller != depositMessage.from) {
      revert UnAuthorizedCaller();
    }

    if (depositMessage.depositType != IL1BridgeMessenger.DepositType.ERC20) {
      revert InvalidDepositType();
    }

    // L1BridgeMessenger to verify if the deposit can be cancelled
    IL1BridgeMessenger(messenger).cancelDeposit(messageHash);

    // Decode the message to extract the token address and the original sender (_from)
    (address l1TokenAddress, , address depositorAddress, , uint256 l1TokenAmount, ) = abi.decode(
      depositMessage.message,
      (address, address, address, address, uint256, bytes)
    );

    // refund the deposited ERC20 tokens to the depositor
    ERC20(l1TokenAddress).safeTransfer(depositorAddress, l1TokenAmount);

    emit DepositCancelled(messageHash, l1TokenAddress, depositorAddress, l1TokenAmount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                             INTERNAL-FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @dev Internal function to transfer ERC20 token to this contract.
  /// @param _token The address of token to transfer.
  /// @param _amount The amount of token to transfer.
  /// @param _data The data passed by caller.
  function _transferERC20In(
    address _token,
    uint256 _amount,
    bytes memory _data
  ) internal returns (address, uint256, bytes memory) {
    address _sender = _msgSender();
    address _from = _sender;
    if (router == _sender) {
      // Extract the sender as this call is from L1BridgeRouter.
      (_from, _data) = abi.decode(_data, (address, bytes));
      _amount = IL1BridgeRouter(_sender).pullERC20(_from, _token, _amount);
    } else {
      uint256 _before = ERC20(_token).balanceOf(address(this));
      ERC20(_token).safeTransferFrom(_from, address(this), _amount);
      uint256 _after = ERC20(_token).balanceOf(address(this));
      _amount = _after - _before;
    }
    // ignore weird fee on transfer token
    require(_amount > 0, "deposit zero amount");

    return (_from, _amount, _data);
  }

  /// @dev Internal function to do all the deposit operations.
  ///
  /// @param _token The token to deposit.
  /// @param _to The recipient address to recieve the token in L2.
  /// @param _amount The amount of token to deposit.
  /// @param _data Optional data to forward to recipient's account.
  /// @param _gasLimit Gas limit required to complete the deposit on L2.
  function _deposit(
    address _token,
    address _to,
    uint256 _amount,
    bytes memory _data,
    uint256 _gasLimit
  ) internal virtual nonReentrant {
    address _l2Token = tokenMapping[_token];
    require(_l2Token != address(0), "no corresponding l2 token");

    // Transfer token into Bridge contract
    address _from;
    (_from, _amount, _data) = _transferERC20In(_token, _amount, _data);

    // Generate message passed to L2ERC20Bridge
    bytes memory _message = abi.encodeCall(
      IL2ERC20Bridge.finalizeDepositERC20,
      (_token, _l2Token, _from, _to, _amount, _data)
    );

    // Send message to L1BridgeMessenger.
    IL1BridgeMessenger(messenger).sendMessage{ value: msg.value }(
      IL1BridgeMessenger.DepositType.ERC20,
      counterpartyBridge,
      0,
      _message,
      _gasLimit,
      _from
    );

    emit DepositERC20(_token, _l2Token, _from, _to, _amount, _data);
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return interfaceId == type(IL1Bridge).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
