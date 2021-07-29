import React, { useEffect, useRef } from 'react'
import Modal from 'react-modal'

import SimpleInput from '../elements/SimpleInput'

import FactoryABI from "../contracts/GroupDeployer.json"
import PoolMachineABI from "../contracts/PoolMachine.json"

const NETWORK_ID = "3"
const Home = ({ initialized, provider, showModalState, ethers }) => {
    const factory = useRef(null);
    const newGroupData = useRef({
        name: "",
        descr: "",
        tokenAdx: "",
        acceptedRate: "",
        tokenName: "",
        tokenSymb: "",
        loanDuration: "",
        interestRate: ""
    })

    const inputStyle = "w-full border p-2 focus:outline-none focus:ring rounded-lg focus:ring-red-300"

    useEffect(() => {
        if (initialized)
            factory.current = new ethers.Contract(FactoryABI.networks[NETWORK_ID].address, FactoryABI.abi, provider.getSigner())
        console.log(factory.current)
    }, [initialized])

    const GroupCreateClick = async () => {
        let name = ethers.utils.formatBytes32String(newGroupData.current.name)
        console.log(await factory.current.nameToApp(name))
        return;
        let infoHash = ethers.utils.formatBytes32String("SampleIPFSHash")

        await factory.current.createNewGroup(name, 
            "0xBF6201a6c48B56d8577eDD079b84716BB4918E8A",
            newGroupData.current.acceptedRate,
            newGroupData.current.tokenName,
            newGroupData.current.tokenSymb,
            newGroupData.current.loanDuration,
            newGroupData.current.interestRate,
            infoHash
        )
        console.log(await factory.current.nameToApp(name))
        console.log(newGroupData)
        showModalState[1](false)
    }

    return (
        <div>
            <Modal isOpen={showModalState[0]} onRequestClose={() => showModalState[1](false)} ariaHideApp={false}>
                <div className="sm:w-3/4 w-full flex flex-col items-center text-center mx-auto space-y-4">
                    <h1 className="text-4xl bg-red-400 py-2 px-8 rounded-lg text-white mt-12 mb-6">Create a new group</h1>
                    <input type="text" placeholder="Name" onChange={e => newGroupData.current.name = e.target.value} className={inputStyle} />
                    <input type="text" placeholder="Description" onChange={e => newGroupData.current.descr = e.target.value} className={inputStyle} />
                    <input type="text" placeholder="Accepted Token" onChange={e => newGroupData.current.tokenAdx = e.target.value} className={inputStyle} />
                    {/* Convert below to wei (or such formats) */}
                    <input type="text" placeholder="Accepted Rate" onChange={e => newGroupData.current.acceptedRate = e.target.value} className={inputStyle} />
                    <input type="text" placeholder="Group Token Name" onChange={e => newGroupData.current.tokenName = e.target.value} className={inputStyle} />
                    <input type="text" placeholder="Token Symbol" onChange={e => newGroupData.current.tokenSymb = e.target.value} className={inputStyle} />
                    {/* Add a selector for days, week, month and input for the number of those */}
                    <div className="flex space-x-2 items-center w-full">
                        <input type="text" placeholder="Max Loan Duration" onChange={e => newGroupData.current.loanDuration = e.target.value} className={inputStyle} />
                        <span>/month</span>
                    </div>
                    {/* Convert from decimalled number to uint16 */}
                    <input type="text" placeholder="Interest Rate" onChange={e => newGroupData.current.interestRate = e.target.value} className={inputStyle} />
                    <button className="bg-red-400 hover:bg-red-300 py-2 px-4 text-white rounded-lg" onClick={GroupCreateClick}>Create</button>
                </div>
            </Modal>

            {/* HEADING AND BODY */}
            <div className="mx-auto md:w-3/4 text-center p-4 bg-red-300">
                <h1 className="text-4xl">Groups</h1>
                <button onClick={() => showModalState[1](true)} className="p-2 bg-blue-500 rounded-lg text-white my-2">Create New Group</button>
                {/* ITEMS */}
                <div className="border rounded-lg pr-4 h-12 flex justify-between items-center overflow-hidden bg-white ">
                    <div className="flex space-x-4 items-center">
                        <div className="px-4 h-16 border-r bg-gray-100 flex items-center">1</div>
                        <span>Test Group</span>
                    </div>
                    <div className="font-bold">TEST</div>
                </div>
            </div>
        </div>
    )
}

export default Home
