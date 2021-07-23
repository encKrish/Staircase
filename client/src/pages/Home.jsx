import React, { useState } from 'react'
import CampaignTypeSelector from '../components/CampaignTypeSelector'
import TopNav from '../components/TopNav'
const Home = () => {
    const campaignTypeState = useState(0);

    return (
        <div>
            <TopNav />
            <CampaignTypeSelector campaignTypeState={campaignTypeState} />
        </div>
    )
}

export default Home
