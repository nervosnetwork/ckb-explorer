import React, { useState, useEffect, useContext } from 'react'
import { RouteComponentProps, Link } from 'react-router-dom'
import Pagination from 'rc-pagination'
import 'rc-pagination/assets/index.css'
import localeInfo from 'rc-pagination/lib/locale/en_US'
import queryString from 'query-string'
import {
  BlockDetailPanel,
  BlockDetailTitlePanel,
  BlockOverviewPanel,
  BlockCommonContent,
  BlockMultiLinesPanel,
  BlockPreviousNextPanel,
  BlockHightLabel,
  BlockTransactionsPanel,
  BlockTransactionsPagition,
} from './styled'
import AppContext from '../../contexts/App'
import Content from '../../components/Content'
import TransactionComponent from '../../components/Transaction'
import SimpleLabel from '../../components/Label'
import TransactionCard from '../../components/Card/TransactionCard'
import CopyIcon from '../../asserts/copy.png'
import BlockHeightIcon from '../../asserts/block_height_green.png'
import BlockTransactionIcon from '../../asserts/transactions_green.png'
import ProposalTransactionsIcon from '../../asserts/proposal_transactions.png'
import TimestampIcon from '../../asserts/timestamp_green.png'
import UncleCountIcon from '../../asserts/uncle_count.png'
import MinerIcon from '../../asserts/miner_green.png'
import BlockRewardIcon from '../../asserts/block_reward.png'
import TransactionFeeIcon from '../../asserts/transaction_fee.png'
import DifficultyIcon from '../../asserts/difficulty.png'
import NonceIcon from '../../asserts/nonce.png'
import ProofIcon from '../../asserts/proof.png'
import EpochIcon from '../../asserts/epoch.png'
import StartNumberIcon from '../../asserts/start_number.png'
import LengthIcon from '../../asserts/length.png'
import PreviousBlockIcon from '../../asserts/left_arrow.png'
import PreviousBlockGreyIcon from '../../asserts/left_arrow_grey.png'
import NextBlockIcon from '../../asserts/right_arrow.png'
import NextBlockGreyIcon from '../../asserts/right_arrow_grey.png'
import MouseIcon from '../../asserts/block_mouse.png'
import TransactionsRootIcon from '../../asserts/transactions_root.png'
import WitnessRootIcon from '../../asserts/witness_root.png'
import { Block, BlockWrapper } from '../../http/response/Block'
import { parseSimpleDate } from '../../utils/date'
import { Response } from '../../http/response/Response'
import { TransactionWrapper } from '../../http/response/Transaction'
import { fetchBlockByHash, fetchTransactionsByBlockHash, fetchBlockByNumber } from '../../http/fetcher'
import { copyElementValue, shannonToCkb } from '../../utils/util'
import { validNumber, startEndEllipsis } from '../../utils/string'
import browserHistory from '../../routes/history'

const BlockDetailTitle = ({ hash }: { hash: string }) => {
  const appContext = useContext(AppContext)
  return (
    <BlockDetailTitlePanel>
      <div className="block__title">Block</div>
      <div className="block__content">
        <code id="block__hash">{hash}</code>
        <div
          role="button"
          tabIndex={-1}
          onKeyDown={() => {}}
          onClick={() => {
            copyElementValue(document.getElementById('block__hash'))
            appContext.toastMessage('Copied', 3000)
          }}
        >
          <img src={CopyIcon} alt="copy" />
        </div>
      </div>
    </BlockDetailTitlePanel>
  )
}

const BlockOverview = ({ value }: { value: string }) => {
  return <BlockOverviewPanel>{value}</BlockOverviewPanel>
}

const BlockPreviousNext = ({
  blockNumber,
  hasPrev = true,
  hasNext = true,
}: {
  blockNumber: any
  hasPrev?: boolean
  hasNext?: boolean
}) => {
  return (
    <BlockPreviousNextPanel>
      {hasPrev ? (
        <div
          role="button"
          tabIndex={-1}
          className="block__arrow"
          onClick={() => {
            browserHistory.push(`/block/${blockNumber - 1}`)
          }}
          onKeyUp={() => {}}
        >
          <img src={PreviousBlockIcon} alt="previous block" />
        </div>
      ) : (
        <div className="block__arrow_grey">
          <img src={PreviousBlockGreyIcon} alt="previous block" />
        </div>
      )}
      <img className="block__mouse" src={MouseIcon} alt="mouse" />
      {hasNext ? (
        <div
          role="button"
          tabIndex={-1}
          className="block__arrow"
          onClick={() => {
            browserHistory.push(`/block/${blockNumber + 1}`)
          }}
          onKeyUp={() => {}}
        >
          <img src={NextBlockIcon} alt="next block" />
        </div>
      ) : (
        <div role="button" tabIndex={-1} className="block__arrow_grey">
          <img src={NextBlockGreyIcon} alt="next block" />
        </div>
      )}
    </BlockPreviousNextPanel>
  )
}

const MultiLinesItem = ({ label, value }: { label: string; value: string }) => {
  return (
    <BlockMultiLinesPanel>
      <div>{label}</div>
      <code>{value}</code>
    </BlockMultiLinesPanel>
  )
}

interface BlockItem {
  image: any
  label: string
  value: string
}

enum PageParams {
  PageNo = 1,
  PageSize = 10,
}

export default (props: React.PropsWithoutRef<RouteComponentProps<{ hash: string }>>) => {
  const { match, location } = props
  const { params } = match
  const { hash } = params

  const { search } = location
  const parsed = queryString.parse(search)
  const { page, size } = parsed

  const appContext = useContext(AppContext)

  const initBlock: Block = {
    block_hash: '',
    number: 0,
    transactions_count: 0,
    proposal_transactions_count: 0,
    uncles_count: 0,
    uncle_block_hashes: [],
    reward: 0,
    total_transaction_fee: 0,
    cell_consumed: 0,
    total_cell_capacity: 0,
    miner_hash: '',
    timestamp: 0,
    difficulty: '',
    start_number: 0,
    epoch: 0,
    length: '',
    version: 0,
    nonce: 0,
    proof: '',
    transactions_root: '',
    witnesses_root: '',
  }
  const [blockData, setBlockData] = useState(initBlock)
  const initTransactionWrappers: TransactionWrapper[] = []
  const [transactionWrappers, setTransactionWrappers] = useState(initTransactionWrappers)
  const [totalTransactions, setTotalTransactions] = useState(1)
  const [pageNo, setPageNo] = useState(validNumber(page, PageParams.PageNo))
  const [pageSize, setPageSize] = useState(validNumber(size, PageParams.PageSize))
  const [hasPrev, setHasPrev] = useState(true)
  const [hasNext, setHasNext] = useState(true)

  const getTransactions = (block_hash: string, page_p: number, size_p: number) => {
    fetchTransactionsByBlockHash(block_hash, page_p, size_p)
      .then(json => {
        const { data, meta } = json as Response<TransactionWrapper[]>
        if (meta) {
          const { total } = meta
          setTotalTransactions(total)
        }
        setTransactionWrappers(data)
      })
      .catch(() => {
        browserHistory.push('/search/fail')
      })
  }

  const checkBlockByNumber = (blockNumber: string) => {
    fetchBlockByNumber(blockNumber)
      .then(json => {
        const { data } = json as Response<BlockWrapper>
        setHasNext(data.attributes.number > 0)
      })
      .catch(() => {
        setHasNext(false)
      })
  }

  const updateBlockPrevNext = (blockNumber: number) => {
    setHasPrev(blockNumber > 0)
    const nextBlockNumber = `${blockNumber + 1}`
    checkBlockByNumber(nextBlockNumber)
  }

  const getBlockByHash = () => {
    appContext.showLoading()
    fetchBlockByHash(hash)
      .then(json => {
        const { data, error } = json as Response<BlockWrapper>
        if (error) {
          browserHistory.push(`/search/fail?q=${hash}`)
        } else {
          const block = data.attributes as Block
          setBlockData(block)
          updateBlockPrevNext(block.number)
          const page_p = validNumber(page, PageParams.PageNo)
          const size_p = validNumber(size, PageParams.PageSize)
          getTransactions(data.attributes.block_hash, page_p, size_p)
        }
        appContext.hideLoading()
      })
      .catch(() => {
        appContext.hideLoading()
        appContext.toastMessage('Network exception, please try again later', 3000)
      })
  }

  useEffect(() => {
    getBlockByHash()
    const page_p = validNumber(page, PageParams.PageNo)
    const size_p = validNumber(size, PageParams.PageSize)
    setPageNo(page_p)
    setPageSize(size_p)
  }, [search, window.location.href])

  const onChange = (page_p: number, size_p: number) => {
    setPageNo(page_p)
    setPageSize(size_p)
    props.history.push(`/block/${hash}?page=${page_p}&size=${size_p}`)
  }

  const BlockLeftItems: BlockItem[] = [
    {
      image: BlockHeightIcon,
      label: 'Block Height:',
      value: `${blockData.number}`,
    },
    {
      image: BlockTransactionIcon,
      label: 'Transactions:',
      value: `${blockData.transactions_count}`,
    },
    {
      image: ProposalTransactionsIcon,
      label: 'Proposal Transactions:',
      value: `${blockData.proposal_transactions_count ? blockData.proposal_transactions_count : 0}`,
    },
    {
      image: BlockRewardIcon,
      label: 'Block Reward:',
      value: `${shannonToCkb(blockData.reward)} CKB`,
    },
    {
      image: TransactionFeeIcon,
      label: 'Transaction Fee:',
      value: `${blockData.total_transaction_fee} Shannon`,
    },
    {
      image: TimestampIcon,
      label: 'Timestamp:',
      value: `${parseSimpleDate(blockData.timestamp)}`,
    },
    {
      image: UncleCountIcon,
      label: 'Uncle Count:',
      value: `${blockData.uncles_count}`,
    },
  ]

  const BlockRightItems: BlockItem[] = [
    {
      image: MinerIcon,
      label: 'Miner:',
      value: blockData.miner_hash,
    },
    {
      image: EpochIcon,
      label: 'Epoch:',
      value: `${blockData.epoch}`,
    },
    {
      image: StartNumberIcon,
      label: 'Epoch Start Number:',
      value: `${blockData.start_number}`,
    },
    {
      image: LengthIcon,
      label: 'Epoch Length:',
      value: blockData.length,
    },
    {
      image: DifficultyIcon,
      label: 'Difficulty:',
      value: `${parseInt(blockData.difficulty, 16)}`,
    },
    {
      image: NonceIcon,
      label: 'Nonce:',
      value: `${blockData.nonce}`,
    },
    {
      image: ProofIcon,
      label: 'Proof:',
      value: `${window.innerWidth > 700 ? blockData.proof : startEndEllipsis(blockData.proof, 9)}`,
    },
  ]

  const BlockRootInfoItems: BlockItem[] = [
    {
      image: TransactionsRootIcon,
      label: 'Transactions Root:',
      value: `${blockData.transactions_root}`,
    },
    {
      image: WitnessRootIcon,
      label: 'Witnesses Root:',
      value: `${blockData.witnesses_root}`,
    },
  ]

  return (
    <Content>
      <BlockDetailPanel width={window.innerWidth} className="container">
        <BlockDetailTitle hash={blockData.block_hash} />
        <BlockOverview value="Overview" />
        <BlockCommonContent>
          <div>
            <div>
              {BlockLeftItems.map(item => {
                return item && <SimpleLabel key={item.label} image={item.image} label={item.label} value={item.value} />
              })}
            </div>
            <div>
              <div>
                {BlockRightItems[0].value ? (
                  <Link
                    to={{
                      pathname: `/address/${BlockRightItems[0].value}`,
                    }}
                  >
                    <SimpleLabel
                      image={BlockRightItems[0].image}
                      label={BlockRightItems[0].label}
                      value={startEndEllipsis(BlockRightItems[0].value, window.innerWidth > 700 ? 8 : 5)}
                      style={{
                        fontFamily: 'source-code-pro, Menlo, Monaco, Consolas, Courier New, monospace',
                      }}
                      highLight
                    />
                  </Link>
                ) : (
                  <SimpleLabel
                    image={BlockRightItems[0].image}
                    label={BlockRightItems[0].label}
                    value="Unable to decode address"
                  />
                )}
                {BlockRightItems.slice(1).map(item => {
                  return (
                    item && <SimpleLabel key={item.label} image={item.image} label={item.label} value={item.value} />
                  )
                })}
              </div>
            </div>
          </div>
          <div>
            {BlockRootInfoItems.map(item => {
              return (
                item &&
                (window.innerWidth > 700 ? (
                  <SimpleLabel
                    key={item.label}
                    image={item.image}
                    label={item.label}
                    value={item.value}
                    lengthNoLimit
                  />
                ) : (
                  <MultiLinesItem key={item.label} label={item.label} value={item.value} />
                ))
              )
            })}
          </div>
        </BlockCommonContent>
        <BlockPreviousNext blockNumber={blockData.number} hasPrev={hasPrev} hasNext={hasNext} />
        <BlockHightLabel>Block Height</BlockHightLabel>

        <BlockTransactionsPanel>
          <BlockOverview value="Transactions" />
          <div>
            {window.innerWidth > 700 &&
              transactionWrappers &&
              transactionWrappers.map((transaction: any) => {
                return (
                  transaction && (
                    <TransactionComponent
                      transaction={transaction.attributes}
                      key={transaction.attributes.transaction_hash}
                      isBlock
                    />
                  )
                )
              })}

            {window.innerWidth <= 700 &&
              transactionWrappers &&
              transactionWrappers.map((transaction: any) => {
                return (
                  transaction && (
                    <TransactionCard
                      transaction={transaction.attributes}
                      key={transaction.attributes.transaction_hash}
                    />
                  )
                )
              })}
          </div>
          <BlockTransactionsPagition>
            {window.innerWidth > 700 ? (
              <Pagination
                showQuickJumper
                showSizeChanger
                defaultPageSize={pageSize}
                pageSize={pageSize}
                defaultCurrent={pageNo}
                current={pageNo}
                total={totalTransactions}
                onChange={onChange}
                locale={localeInfo}
              />
            ) : (
              <Pagination
                showSizeChanger
                defaultPageSize={pageSize}
                pageSize={pageSize}
                defaultCurrent={pageNo}
                current={pageNo}
                total={totalTransactions}
                onChange={onChange}
                locale={localeInfo}
              />
            )}
          </BlockTransactionsPagition>
        </BlockTransactionsPanel>
      </BlockDetailPanel>
    </Content>
  )
}
