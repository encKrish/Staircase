// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.7.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {GroupDeployer} from "./GroupDeployer.sol";

contract GroupFactory {
    ISuperfluid private host; // host
    IConstantFlowAgreementV1 private cfa; // the stored constant flow agreement class address
    ISuperTokenFactory private superTokenFactory;

    struct GroupAdx {
        address deployer;
        address app;
        address acceptedToken;
        address poolToken;
    }

    mapping(string => GroupAdx) nameToGrp;

    constructor(
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa,
        ISuperTokenFactory _superTokenFactory,
    ) {
        host = _host;
        cfa = _cfa;
        superTokenFactory = _superTokenFactory;
    }

    function createNewGroup(
        string groupName,
        ISuperToken _acceptedToken,
        int96 _acceptedRate,
        string memory token_name,
        string memory token_symbol,
        uint _loanDuration,
        uint16 _interestRate
    ) public {
        GroupDeployer _gd = new GroupDeployer(host,
            cfa,
            _acceptedToken,
            superTokenFactory,
            _acceptedToken,
            _acceptedRate,
            token_name,
            token_symbol,
            _loanDuration,
            _interestRate    
        )

        //Upgrade the code to take only address of regular acceptedToken and find the super token for the address using SuperTokenFactory. One project used tghis in Github. I have starred this.
        nameToGrp[groupName] = GroupAdx(address(_gd), address(_gd.poolMachine), address(_acceptedToken), address(_gd.poolToken));

    }
}