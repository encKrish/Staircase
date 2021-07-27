// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

import {Simple777Recipient} from "./Simple777Recipient.sol";
import {Ballot} from "../DAO/Ballot.sol";

contract PoolMachine is Simple777Recipient, SuperAppBase, Ballot {   
    event NewAccountBlacklisted(address defaulter);
    // InFlow Streams should always be stablecoin based for 2 reasons:
    // 1. It makes sending poolTokens magnitudes easier.
    // 2. It is microfinance, you shouldn't have high volatile coins here. 

    // TODO check for due loans, if not paid, revoke membership and blacklist
    
    ISuperfluid private host;   
    IConstantFlowAgreementV1 private cfa;
    ISuperToken private acceptedToken;
    int96 public acceptedRate;
    ISuperToken private poolToken;
    uint16 public renounceFee = 400; // Arbitrary value set (_ _ _ _ _ => _ _ _._ _ %)
    uint16 public interestRate;
    uint public loanDuration;

    constructor(
        ISuperfluid _host,
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _acceptedToken,
        int96 _acceptedRate,
        ISuperToken _poolToken,
        uint _loanDuration,
        uint16 _interestRate
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
        loanDuration = _loanDuration;
        interestRate = _interestRate;

        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;
            
        host.registerApp(configWord);
    }

    function repayLoan(uint proposalId) public onlyVoter ofPropType(proposalId, 1) {
        FundsAlloted storage fundDescr = proposalIdToFunds[proposalId];
        uint allotTime = block.time - fundDescr.blockTime;
        uint amount = fundDescr.amount - fundDescr.amountRecievedBack;
        uint amountToPay;
        {
            uint interest += (allotTime * interestRate) / ((365 Days ) * 10000) * amount;
            amountToPay = amount + interest;
        }
        acceptedToken.send(address(this), amountToPay, "");

        fundDescr.amountRecievedBack += amount;
        fundDescr.paidBack = true;

        emit LoanRepaid(proposalId);
    }

    function repayPartialLoan(uint proposalId, uint amountToPay) public onlyVoter ofPropType(proposalId, 1) {
        FundsAlloted storage fundDescr = proposalIdToFunds[proposalId];
        uint allotTime = block.time - fundDescr.blockTime;
        
        // TODO check this!!!
        uint amount = (amountToPay * (365 Days) * 10000) / ((10000 * (365 Days)) + (interestRate * interestRate))

        acceptedToken.send(address(this), amountToPay, "");

        fundDescr.amountRecievedBack += amount;
    }

    function renounceOwnership() public onlyVoter {
        uint senderBalance = poolToken.balanceOf(msg.sender);
        poolToken.send(address(this), senderBalance, "");

        uint amountToSend = (senderBalance * (10000 - renounceFee)) / 10000;
        require(getPoolBalance() > amountToSend, "Pool's balance is not enough currently");
        acceptedToken.send(msg.sender, amountToSend, "");
    }

    function _updateOutflow(
        bytes calldata ctx,
        address donor,
        bytes32 agreementId
    ) private returns (bytes memory newCtx) {
        newCtx = ctx;

        // If we "stream out" acceptedToken, we will get a -ve inFlowRate (outflowRate)
        (, int96 inFlowRate, , ) = cfa.getFlowByID(
            acceptedToken,
            agreementId
        );
        
        (, int96 outFlowRate, , ) = cfa.getFlow(
            poolToken,
            address(this),
            donor
        );
        
        if (voters[donor].isVoter) {
            if  (inFlowRate != acceptedRate) {
                // inFlowRate is not equal to acceptedRate, delete inFlow, zero outFlow
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
                voters[donor].isVoter = false;

                // The donor already recieves an outflow (flow is updated)
                if (outFlowRate > 0) {
                    (newCtx, ) = host.callAgreementWithContext(
                        cfa,
                        abi.encodeWithSelector(
                            cfa.deleteFlow.selector,
                            poolToken,
                            address(this),
                            donor,
                            new bytes(0) // placeholder
                        ),
                        "0x",
                        newCtx
                    );
                }
            }
            else {
                // If inFlowRate is equal to acceptedRate
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
                voters[donor].isVoter = true;
            }
        }
    }

    function _stopAllFlow(
        bytes calldata ctx,
        address donor,
        bytes32 agreementId
    ) private returns (bytes memory newCtx) {
        (, int96 inFlowRate, , ) = cfa.getFlowByID(
            acceptedToken,
            agreementId
        );
        
        (, int96 outFlowRate, , ) = cfa.getFlow(
            poolToken,
            address(this),
            donor
        );

        newCtx = ctx;
        if(inFlowRate > 0) {
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
        }
        if(outFlowRate > 0) {
            (newCtx, ) = host.callAgreementWithContext(
                    cfa,
                    abi.encodeWithSelector(
                        cfa.deleteFlow.selector,
                        poolToken,
                        address(this),
                        donor,
                        new bytes(0) // placeholder
                    ),
                    "0x",
                    newCtx
                );
        }

        return newCtx;
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
        
        // return _updateOutflow(_ctx, donor, _agreementId);
        return _stopAllFlow(_ctx, donor, _agreementId);
    }

    function getNetInFlow() public view returns (int96) {
        return cfa.getNetFlow(acceptedToken, address(this));
    }

    function getPoolBalance() public view returns(uint) {
        return acceptedToken.balanceOf(address(this));
    }

    function getPoolTokenBalance() public view returns(uint) {
        return poolToken.balanceOf(address(this));
    }

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

    // DEBUG: Create a function to mint super token to some address
    // Will be used to send the tokens back to the app and test functions

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
