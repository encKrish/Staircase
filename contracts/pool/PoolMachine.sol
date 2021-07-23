// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

import {Simple777Recipient} from "./Simple777Recipient.sol";

contract PoolMachine is Simple777Recipient, SuperAppBase {    
    ISuperfluid private host;
    IConstantFlowAgreementV1 private cfa;
    ISuperToken private acceptedToken;
    address private reciever;
    ISuperToken private poolToken;

    address creator;
    mapping(address => bool) allMembers;
    mapping(address => bool) activeMembers;
    uint public acceptedRate;
    
    mapping(address => uint) donorsToAmount; // use chainlink to calculate amount in dollars

    constructor(
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _acceptedToken,
        uint _acceptedRate,
        ISuperToken _poolToken,
    ) Simple777Recipient(address(poolToken)) {
        assert(address(_host) != address(0));
        assert(address(_cfa) != address(0));
        assert(address(_acceptedToken) != address(0));
        assert(_acceptedRate != 0);
        assert(address(_poolToken) != address(0));

        host = _host;
        cfa = _cfa;
        acceptedToken = _acceptedToken;
        acceptedRate = _acceptedRate;
        poolToken = _poolToken;

        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;
            
        host.registerApp(configWord);
        creator = tx.origin;
    }

    function _updateOutflow(
        bytes calldata ctx,
        address donor,
        bytes32 agreementId
    ) private returns (bytes memory newCtx) {
        newCtx = ctx;
        (, int96 inFlowRate, , ) = cfa.getFlowByID(
            acceptedToken,
            agreementId
        );
        (, int96 outFlowRate, , ) = cfa.getFlow(
            poolToken,
            address(this),
            donor
        );
        
        if (inFlowRate < 0) inFlowRate = -inFlowRate; // Fixes issue when inFlowRate is negative

        if (allMembers[donor]) {
            if  (inFlowRate != acceptedRate) {
                (newCtx, ) = host.callAgreementWithContext(
                    cfa,
                    abi.encodeWithSelector(
                        cfa.deleteFlow.selector,
                        acceptedToken,
                        donor,
                        address(this),
                        new bytes(0) // placeholder
                    ),
                    "0x",
                    newCtx
                );
                activeMembers[donor] = false;
            }
            else {
                (newCtx, ) = host.callAgreementWithContext(
                    cfa,
                    abi.encodeWithSelector(
                        cfa.createFlow.selector,
                        poolToken,
                        donor,
                        inFlowRate,
                        new bytes(0) // placeholder
                    ),
                    "0x",
                    newCtx
                );
                activeMembers[donor] = true;
            }
        }
        // else {
        //     // add logic for non-member 
        // }
    }

    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/
    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, // _cbdata,
        bytes calldata _ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        address donor = host.decodeCtx(_ctx).msgSender;
        return _updateOutflow(_ctx, donor, _agreementId);
    }

    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, //_cbdata,
        bytes calldata _ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        address donor = host.decodeCtx(_ctx).msgSender;
        return _updateOutflow(_ctx, donor, _agreementId);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata _agreementData,
        bytes calldata, //_cbdata,
        bytes calldata _ctx
    ) external override onlyHost returns (bytes memory newCtx) {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isSameToken(_superToken) || !_isCFAv1(_agreementClass))
            return _ctx;
        (address donor, ) = abi.decode(_agreementData, (address, address));
        return _updateOutflow(_ctx, donor, _agreementId);
    }

    function getNetFlow() public view returns (int96) {
        return cfa.getNetFlow(acceptedToken, address(this));
    }

    function getBalance() public view returns(uint) {return 0;}

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return
            ISuperAgreement(agreementClass).agreementType() ==
            keccak256(
                "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
            );
    }

    modifier onlyHost() {
        require(
            msg.sender == address(host),
            "SatisfyFlows: support only one host"
        );
        _;
    }
    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "SatisfyFlows: not accepted token");
        require(_isCFAv1(agreementClass), "SatisfyFlows: only CFAv1 supported");
        _;
    }
}
