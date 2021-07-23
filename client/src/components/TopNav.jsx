import React from 'react'
import { BsArrowRightShort } from 'react-icons/bs'
import Logo from '../logo.svg'

const TopNav = () => {
    return (
        <nav className="p-3 flex justify-between items-center">
            <span><img src={Logo} alt="" /></span>
            <div className="space-x-2 flex items-center">
                <a href="#" className="cursor-pointer text-gray-600 hover:underline font-bold tracking-wider text-md">Docs</a>
                <button className="font-bold py-2 px-4 text-indigo-400 hover:text-indigo-300 flex space-x-1">
                    <span>Connect to a wallet</span>
                    <BsArrowRightShort className="text-xl" />
                </button>
            </div>
        </nav>
    )
}

export default TopNav
