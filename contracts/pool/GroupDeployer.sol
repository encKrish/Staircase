// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.7.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {INativeSuperToken, NativeSuperTokenProxy} from "./NativeSuperToken.sol";
import {PoolMachine} from "./PoolMachine.sol";

contract GroupDeployer {
    event NewGroupFormed(address _contract);

    ISuperfluid private host; // host
    IConstantFlowAgreementV1 private cfa; // the stored constant flow agreement class address
    ISuperToken private acceptedToken; // accepted token
    ISuperTokenFactory private superTokenFactory;
    INativeSuperToken public poolToken;
    address public poolMachine;

    constructor(
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa,
        ISuperTokenFactory _superTokenFactory,
        ISuperToken _acceptedToken,
        int96 _acceptedRate,
        string memory token_name,
        string memory token_symbol,
        uint _loanDuration,
        uint16 _interestRate
    ) {
        host = _host;
        cfa = _cfa;
        acceptedToken = _acceptedToken;
        superTokenFactory = _superTokenFactory;
        total_supply = total_supply * (10**18);

        step1_deploy(_acceptedRate, );
        step2_initProxy();
        step3_initToken(token_name, token_symbol);
    }

    function step1_deploy(int96 _acceptedRate, uint _loanDuration, uint16 _interestRate) internal {
        // Deploy the Custom Super Token proxy
        poolToken = INativeSuperToken(address(new NativeSuperTokenProxy()));

        // Deploy the machine using the new pool token address
        poolMachine = address(
            new PoolMachine(
                host,
                cfa,
                acceptedToken,
                _acceptedRate,
                ISuperToken(address(poolToken)),
                _loanDuration,
                _interestRate
            )
            emit NewGroupFormed(address(poolMachine));    
        );
    }

    function step2_initProxy() internal {
        // Set the proxy to use the Super Token logic managed by Superfluid Protocol Governance
        superTokenFactory.initializeCustomSuperToken(address(poolToken));
    }

    function step3_initToken(
        string memory name,
        string memory symbol
    ) internal {
        // mints a million tokens (equals $1M)
        poolToken.initialize(name, symbol, (10**6)*(10**18), address(poolMachine));
    }
}