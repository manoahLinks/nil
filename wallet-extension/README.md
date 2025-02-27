# <p align="center">=nil; Wallet Extension 🔐</p>

Welcome to the **=nil; Wallet Extension** — a user-friendly way to manage accounts on the **=nil;** blockchain. This extension provides essential tools for interacting with the network or connecting with decentralized applications (dApps). Give it a spin and let us know what you think! 🚀

---

## Roadmap 🛣️

- [ ] **Basic Wallet Features** ⏳
    - Create a new wallet
    - Send & Receive tokens
    - Check your balance
    - Top-up test currencies
- [ ] **Wallet SDK for dApp Developers**
- [ ] **Playground Integration**
- [ ] **Further Improvements & Feature Requests**

---

## Languages 🌐

By default, everything is in **English**. However, we plan to support multiple languages in the near future. We use **i18next** to handle translations, and we'd love to hear which languages you'd like to see!

---

## How to Use ⚙️

1. **Clone** this repository to your local machine
2. Install dependencies:
   ```sh
   npm install
   ```
3. Build the `smart contracts`:
   ```sh
   cd smart-contracts && npm ci && npm run build && cd ..
   ```
4. Build `niljs`:
   ```sh
   cd niljs && npm ci && npm run build && cd ..
   ```
5. Build the `wallet extension`:
   ```sh
   cd wallet-extension && npm ci && npm run build
   ```
   This generates the production files.
6. Load the extension in Chrome:
  - Open **Chrome Extensions** (`chrome://extensions/`)
  - Enable **Developer Mode**
  - Load the generated folder as an **unpacked extension**

That’s it! Enjoy managing your tokens and exploring dApps on the **=nil;** blockchain. If you have questions or suggestions, feel free to open an issue or reach out. 💡
