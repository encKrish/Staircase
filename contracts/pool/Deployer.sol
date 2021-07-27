// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.7.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {INativeSuperToken, NativeSuperTokenProxy} from "./NativeSuperToken.sol";
import {PoolMachine} from "./PoolMachine.sol";

contract Deployer {
    // Deploys token and machine
    event NewContract(address _contract);

    ISuperfluid private host; // host
    IConstantFlowAgreementV1 private cfa; // the stored constant flow agreement class address
    ISuperToken private acceptedToken; // accepted token
    INativeSuperToken public poolToken;
    ISuperTokenFactory private superTokenFactory;
    address public poolMachine;

    // uint256 constant TOTAL_SUPPLY = 100 * (10**18); // 100 tokens represent percentage of pool

    constructor(
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _acceptedToken,
        int96 _acceptedRate,
        ISuperTokenFactory _superTokenFactory,
        string memory token_name,
        string memory token_symbol,
        uint256 total_supply
    ) {
        host = _host;
        cfa = _cfa;
        acceptedToken = _acceptedToken;
        superTokenFactory = _superTokenFactory;
        total_supply = total_supply * (10**18);

        step1_deploy(_acceptedRate);
        step2_initProxy();
        step3_initToken(token_name, token_symbol, total_supply);
    }

    function step1_deploy(int96 _acceptedRate) internal {
        // Deploy the Custom Super Token proxy
        poolToken = INativeSuperToken(address(new NativeSuperTokenProxy()));
        emit NewContract(address(poolToken));

        // Deploy the machine using the new pool token address
        poolMachine = address(
            new PoolMachine(
                host,
                cfa,
                acceptedToken,
                _acceptedRate,
                ISuperToken(address(poolToken))
            )
        );

        // TODO find use, if not any, remove or replace
        emit NewContract(poolMachine);
    }

    function step2_initProxy() internal {
        // Set the proxy to use the Super Token logic managed by Superfluid Protocol Governance
        superTokenFactory.initializeCustomSuperToken(address(poolToken));
    }

    function step3_initToken(
        string memory name,
        string memory symbol,
        uint256 total_supply
    ) internal {
        poolToken.initialize(name, symbol, total_supply, address(poolMachine));
    }
}