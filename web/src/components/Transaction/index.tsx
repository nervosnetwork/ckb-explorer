import React from 'react'
import { Link } from 'react-router-dom'
import { TransactionsCell, TransactionsItem, CellHash, CellHashHighLight } from './styled'
import { parseDate } from '../../utils/date'
import { shannonToCkb } from '../../utils/util'
import { startEndEllipsis } from '../../utils/string'
import InputOutputIcon from '../../assets/input_arrow_output.png'
import { InputOutput } from '../../http/response/Transaction'

const TransactionCell = ({ cell, address }: { cell: any; address?: string }) => {
  const CellbaseAddress = () => {
    return address === cell.address_hash || cell.from_cellbase ? (
      <div className="transaction__cell">
        <CellHash>{cell.from_cellbase ? 'Cellbase' : startEndEllipsis(cell.address_hash)}</CellHash>
      </div>
    ) : (
      <Link className="transaction__cell__link" to={`/address/${cell.address_hash}`}>
        <CellHashHighLight>{startEndEllipsis(cell.address_hash)}</CellHashHighLight>
      </Link>
    )
  }

  return (
    <TransactionsCell>
      {cell.address_hash ? (
        <CellbaseAddress />
      ) : (
        <div className="transaction__cell">
          <CellHash>{cell.from_cellbase ? 'Cellbase' : 'Unable to decode address'}</CellHash>
        </div>
      )}
      {!cell.from_cellbase && <div className="transaction__cell__capacity">{`${shannonToCkb(cell.capacity)} CKB`}</div>}
    </TransactionsCell>
  )
}

const TransactionComponent = ({
  transaction,
  address,
  isBlock = false,
}: {
  transaction: any
  address?: string
  isBlock?: boolean
}) => {
  return (
    <TransactionsItem>
      <div>
        <div className="transaction__hash__panel">
          <Link to={`/transaction/${transaction.transaction_hash}`}>
            <code className="transaction_hash">{transaction.transaction_hash}</code>
          </Link>
          {!isBlock && (
            <div className="transaction_block">
              {`(Block ${transaction.block_number})  ${parseDate(transaction.block_timestamp)}`}
            </div>
          )}
        </div>
        <span className="transaction__separate" />
        <div className="transaction__input__output">
          <div className="transaction__input">
            {transaction.display_inputs &&
              transaction.display_inputs.map((cell: InputOutput) => {
                return cell && <TransactionCell cell={cell} address={address} key={cell.id} />
              })}
          </div>
          <img src={InputOutputIcon} alt="input and output" />
          <div className="transaction__output">
            {transaction.display_outputs &&
              transaction.display_outputs.map((cell: InputOutput) => {
                return cell && <TransactionCell cell={cell} address={address} key={cell.id} />
              })}
          </div>
        </div>
      </div>
    </TransactionsItem>
  )
}

export default TransactionComponent
