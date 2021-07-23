import React from 'react'

const STYLE_MAP = {
    NORMAL: "cursor-pointer h-72 w-60 p-2 bg-white opacity-60 text-gray-600 rounded-lg flex-col transform translate duration-200",
    SELECTED: "cursor-pointer h-72 w-60 p-2 bg-white opacity-100 text-gray-600 rounded-lg flex-col transform scale-105 translate duration-200"
}

const CampaignTypeSelector = ({ campaignTypeState }) => {
    return (
        <nav className="bg-purple-500 flex space-x-5 p-5">
            <div onClick={() => campaignTypeState[1](0)} className={campaignTypeState[0] === 0 ? STYLE_MAP.SELECTED : STYLE_MAP.NORMAL}>
                <img className="rounded-lg h-52 mb-3 object-cover" src="https://unsplash.com/photos/ineC_oi7NHs/download?force=true&w=640" alt="" />
                <p className="font-bold text-xl -mb-1">Creators</p>
                <p className="uppercase tracking-widest text-gray-400 text-xs">FUND YOUR CHAMPS</p>
            </div>

            <div onClick={() => campaignTypeState[1](1)} className={campaignTypeState[0] === 1 ? STYLE_MAP.SELECTED : STYLE_MAP.NORMAL}>
                <img className="rounded-lg h-52 mb-3 object-cover" src="https://unsplash.com/photos/rlbG0p_nQOU/download?force=true&w=640" alt="" />
                <p className="font-bold text-xl -mb-1">Fundraisers</p>
                <p className="uppercase tracking-widest text-gray-400 text-xs">Help a dream</p>
            </div>
        </nav>
    )
}

export default CampaignTypeSelector
