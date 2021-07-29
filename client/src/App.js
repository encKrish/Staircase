import React, { useState, useEffect, useRef } from 'react'
import Modal from 'react-modal'

import Home from './pages/Home'
// Include React-router as soon as new page is added
import { ethers } from "ethers";

import PoolMachineABI from "./contracts/PoolMachine.json"

const NETWORK_ID = "3"
function App() {
  const [initialized, setInitialized] = useState(false)
  const [userAdx, setUserAdx] = useState("")
  const provider = useRef(null);
  const signer = useRef(null);
  const GroupModalState = useState(false)

  const connectWallet = async () => {
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    const account = accounts[0];

    if (window.ethereum) { //check if Metamask is installed
      try {
        const address = await window.ethereum.enable(); //connect Metamask
        const obj = {
          connectedStatus: true,
          status: "",
          address: address,
        }
        return obj;
      } catch (error) {
        return {
          connectedStatus: false,
          status: "🦊 Connect to Metamask using the button on the top right."
        }
      }
    } else {
      return {
        connectedStatus: false,
        status: "🦊 You must install Metamask into your browser: ",
      }
    }
  };

  useEffect(() => {
    provider.current = new ethers.providers.Web3Provider(window.ethereum)
    signer.current = provider.current.getSigner()
  }, [initialized])

  return (
    <div className="App">
      {/* NAV */}
      <div className="h-12 flex justify-between items-center p-4 bg-blue-300 ">
        <span>Staircase</span>
        <div className="flex space-x-4 items-center">
          <span>Home</span>
          <span>Settings</span>
          <button onClick={async () => {
            let res = await connectWallet()
            if (res.connectedStatus) setUserAdx(res.address)
            setInitialized(true)
          }} className="p-2 bg-blue-500">{userAdx ? userAdx : "Connect to wallet"}</button>
        </div>
      </div>

      <Home initialized={initialized} provider={provider.current} showModalState={GroupModalState} ethers={ethers}/>
    </div>

  );
}

export default App;