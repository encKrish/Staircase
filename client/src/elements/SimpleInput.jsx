import React from 'react'

const SimpleInput = ({data}) => {
    return (
        <div>
            <label htmlFor="group-name">Enter group name</label>
            <input name="group-name" type="text" />
        </div>
    )
}

export default SimpleInput
