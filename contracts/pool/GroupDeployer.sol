// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.7.0;

import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {INativeSuperToken, NativeSuperTokenProxy} from "./NativeSuperToken.sol";
import {PoolMachine} from "./PoolMachine.sol";

contract GroupDeployer {
    event NewGroupFormed(address _contract);

    ISuperfluid private host; // host
    IConstantFlowAgreementV1 private cfa; // the stored constant flow agreement class address
    ISuperTokenFactory private superTokenFactory;

    mapping(bytes32 => address) public nameToApp;

    constructor(
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa,
        ISuperTokenFactory _superTokenFactory
    ) {
        host = _host;
        cfa = _cfa;
        superTokenFactory = _superTokenFactory;
    }

    function createNewGroup(
        bytes32 groupName,
        ISuperToken _acceptedToken,
        int96 _acceptedRate,
        string memory token_name,
        string memory token_symbol,
        uint _loanDuration,
        uint16 _interestRate,
        bytes memory _infoHash
    ) public {
        (address poolMachine, INativeSuperToken poolToken) = step1_deploy(_acceptedToken, _acceptedRate, _loanDuration, _interestRate, _infoHash);
        step2_initProxy(poolToken);
        step3_initToken(poolMachine, poolToken, token_name, token_symbol);

        nameToApp[groupName] = poolMachine;

        emit NewGroupFormed(poolMachine);
    }

    function step1_deploy(ISuperToken _acceptedToken, int96 _acceptedRate, uint _loanDuration, uint16 _interestRate, bytes memory _infoHash) internal returns(address, INativeSuperToken) {
        // Deploy the Custom Super Token proxy
        INativeSuperToken poolToken = INativeSuperToken(address(new NativeSuperTokenProxy()));

        // Deploy the machine using the new pool token address
        address poolMachine = address(
            new PoolMachine(
                host,
                cfa,
                _acceptedToken,
                _acceptedRate,
                ISuperToken(address(poolToken)),
                _loanDuration,
                _interestRate,
                _infoHash
            )
        );
        emit NewGroupFormed(address(poolMachine));    

        return (poolMachine, poolToken);
    }

    function step2_initProxy(INativeSuperToken poolToken) internal {
        // Set the proxy to use the Super Token logic managed by Superfluid Protocol Governance
        superTokenFactory.initializeCustomSuperToken(address(poolToken));
    }

    function step3_initToken(
        address poolMachine,
        INativeSuperToken poolToken,
        string memory name,
        string memory symbol
    ) internal {
        // mints a million tokens (equals $1M)
        poolToken.initialize(name, symbol, (10**6)*(10**18), address(poolMachine));
    }
}