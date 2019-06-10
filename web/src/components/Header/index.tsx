import React from 'react'
import styled from 'styled-components'
import { Link } from 'react-router-dom'
import Search from '../Search'
import logoIcon from '../../asserts/ckb_logo.png'
import testnetTipImage from '../../asserts/testnet_tip.png'

const HeaderDiv = styled.div`
  width: 100%;
  min-height: 80px;
  overflow: hidden;
  box-shadow: 0 2px 4px 0 #141414;
  background-color: #424242;
  position: sticky;
  position: -webkit-sticky;
  top: 0;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  padding: 1px 82px;
  @media (max-width: 700px) {
    padding: 1px ${(props: { width: number }) => (150 * props.width) / 1920}px;
  }
  .header__logo,
  .header__menus,
  .header__search {
    display: flex;
    align-items: center;
  }
  .header__logo {
    padding-left: ${(props: { width: number }) => (7 * props.width) / 1920}px;
    .header__logo__img {
      width: 182px;
      height: auto;
    }
  }

  .header__menus {
    padding-top: 26px;
    padding-bottom: 27px;
    padding-left: ${(props: { width: number }) => (41 * props.width) / 1920}px;
    min-height: 75px;
    .header__menus__item {
      margin-left: ${(props: { width: number }) => (92 * props.width) / 1920 / 2}px;
      margin-right: ${(props: { width: number }) => (92 * props.width) / 1920 / 2}px;
      font-size: 22px;
      font-weight: 600;
      @media (max-width: 700px) {
        font-weight: 500;
      }
      line-height: 30px;
      color: #3cc68a;
      &.header__menus__item--active,&: hover {
        color: white;
      }
    }
  }
  .header__search {
    flex: 1;
    justify-content: flex-end;

    @media (max-width: 700px) {
      flex: 1;
      justify-content: flex-start;
    }

    display: flex;
    .header__search__component {
      display: flex;
      align-items: center;
      justify-content: left;
      height: 50px;
      width: ${(props: { width: number }) => (550 * props.width) / 1920}px;
      min-width: 420px;

      @media (max-width: 700px) {
        width: 250px;
        min-width: 200px;
      }
    }

    .header__testnet__panel {
      border-radius: 0 6px 6px 0;
      background-color: #3cc68a;
      margin-left: 3px;

      .header__testnet__flag {
        height: 50px;
        width: 120px;
        color: white;
        font-size: 16px;
        text-align: center;
        line-height: 50px;

        @media (max-width: 700px) {
          font-size: 14px;
          width: 75px;
          height: 40px;
          line-height: 40px;
          margin-left: 0;
        }
      }

      &:hover .header__testnet__tip {
        visibility: visible;
      }

      .header__testnet__tip {
        width: 350px;
        height: 62px;
        position: fixed;
        z-index: 1100;
        right: 90px;
        top: 75px;
        background-image: url(${testnetTipImage});
        background-repeat: no-repeat;
        background-size: 350px 62px;
        visibility: hidden;
        color: white;
        font-size: 16px;
        font-weight: bold;
        padding-top: 3px;
        line-height: 62px;
        text-align: center;
      }

      @media (max-width: 700px) {
        margin-left: 0px;

        .header__testnet__flag {
          font-size: 13px;
          width: 66px;
          height: 40px;
          line-height: 40px;
          margin-left: 0;
        }

        &:hover .header__testnet__tip {
          visibility: hidden;
        }

        .header__testnet__tip {
          visibility: hidden;
        }
      }
    }
  }
  a {
    text-decoration: none;
  }
`

const menus = [
  {
    name: 'Wallet',
    url: 'https://github.com/nervosnetwork/neuron',
  },
  {
    name: 'Docs',
    url: 'https://docs.nervos.org/',
  },
]

export default ({ search = true }: { search?: boolean }) => {
  return (
    <HeaderDiv width={window.innerWidth}>
      <Link to="/" className="header__logo">
        <img className="header__logo__img" src={logoIcon} alt="logo" />
      </Link>
      <div className="header__menus">
        {menus.map((d: any) => {
          return (
            <a key={d.name} className="header__menus__item" href={d.url} target="_blank" rel="noopener noreferrer">
              {d.name}
            </a>
          )
        })}
      </div>
      {search && (
        <div className="header__search">
          <div className="header__search__component">
            <Search />
          </div>
          <div className="header__testnet__panel">
            <div className="header__testnet__flag">TESTNET</div>
            <div className="header__testnet__tip">Mainnet is comming</div>
          </div>
        </div>
      )}
    </HeaderDiv>
  )
}
