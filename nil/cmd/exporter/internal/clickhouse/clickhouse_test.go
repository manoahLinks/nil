package clickhouse

import (
	"context"
	"os/exec"
	"testing"
	"time"

	"github.com/NilFoundation/nil/nil/internal/types"
	"github.com/stretchr/testify/suite"
)

type SuiteClickhouse struct {
	suite.Suite
	clickhouse *exec.Cmd
	driver     *ClickhouseDriver
}

func (s *SuiteClickhouse) SetupSuite() {
	dir := s.T().TempDir()
	clickhouse := exec.Command( //nolint:gosec
		"clickhouse", "server", "--",
		"--listen_host=127.0.0.1",
		"--tcp_port=9003",
		"--http_port=",
		"--mysql_port=",
		"--path="+dir,
	)
	clickhouse.Dir = dir
	err := clickhouse.Start()
	s.Require().NoError(err)
	time.Sleep(1 * time.Second)

	createDb := exec.Command("clickhouse-client", "--port=9003", "--query", "CREATE DATABASE IF NOT EXISTS nil_database")
	_, err = createDb.CombinedOutput()
	s.Require().NoError(err)

	s.driver, err = NewClickhouseDriver(context.Background(), "127.0.0.1:9003", "", "", "nil_database")
	s.Require().NoError(err)
	s.Require().NotNil(s.driver)

	err = setupSchemes(s.T().Context(), s.driver.conn)
	s.Require().NoError(err)
}

func (s *SuiteClickhouse) TearDownSuite() {
	if s.clickhouse != nil {
		err := s.clickhouse.Process.Kill()
		s.Require().NoError(err)
	}
}

// This test should catch cases when new fields are added to the Transaction without supporting them in the driver.
func (s *SuiteClickhouse) TestTransactionWithBinaryBatching() {
	transactionBatch, err := s.driver.conn.PrepareBatch(s.T().Context(), "INSERT INTO transactions")
	s.Require().NoError(err)

	tx := types.NewEmptyTransaction()
	tokenId := types.TokenIdForAddress(types.Address{})
	tx.Token = []types.TokenBalance{{*tokenId, types.NewValueFromUint64(123)}}
	tx.RequestChain = []*types.AsyncRequestInfo{
		{
			Id:     123,
			Caller: types.MainSmartAccountAddress,
		},
	}

	txn := &TransactionWithBinary{Transaction: *tx}

	err = transactionBatch.AppendStruct(txn)
	s.Require().NoError(err)
}

func TestClickhouse(t *testing.T) {
	t.Parallel()
	suite.Run(t, new(SuiteClickhouse))
}
