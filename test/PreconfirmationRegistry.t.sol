// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PreconfirmationRegistry.sol";

contract PreconfirmationRegistryTest is Test {
    PreconfirmationRegistry public registry;
    address public registrant;
    address public proposer;
    uint256 constant MINIMUM_COLLATERAL = 1 ether;

    function setUp() public {
        registry = new PreconfirmationRegistry(MINIMUM_COLLATERAL);
        registrant = vm.addr(1);
        proposer = vm.addr(2);
        vm.deal(registrant, 10 ether);
    }

    function testRegister() public {
        vm.prank(registrant);
        registry.register{value: 2 ether}();

        PreconfirmationRegistry.Registrant memory info = registry.getRegistrantInfo(registrant);
        assertEq(info.balance, 2 ether);
        assertEq(info.frozenBalance, 0);
        assertEq(info.enteredAt, block.number + 32);
        assertEq(info.exitInitiatedAt, 0);
        assertEq(info.delegatedProposers.length, 0);
    }

    function testDelegate() public {
        vm.startPrank(registrant);
        registry.register{value: 2 ether}();
        
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        registry.delegate(proposers);
        vm.stopPrank();

        PreconfirmationRegistry.Registrant memory registrantInfo = registry.getRegistrantInfo(registrant);
        PreconfirmationRegistry.Proposer memory proposerInfo = registry.getProposerInfo(proposer);
        assertEq(registrantInfo.delegatedProposers.length, 1);
        assertEq(registrantInfo.delegatedProposers[0], proposer);
        assertEq(proposerInfo.delegatedBy.length, 1);
        assertEq(proposerInfo.delegatedBy[0], registrant);

        // we do not test that the effective collateral is calculated correctly here, that is done in the testUpdateStatus test
    }

    function testUpdateStatus() public {
        vm.startPrank(registrant);
        registry.register{value: 2 ether}();
        
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        registry.delegate(proposers);
        vm.stopPrank();

        vm.roll(block.number + 32);

        registry.updateStatus(proposers);

        PreconfirmationRegistry.Status status = registry.getProposerStatus(proposer);
        assertEq(uint(status), uint(PreconfirmationRegistry.Status.PRECONFER));
    }

    function testApplyPenalty() public {
        // This test is a placeholder and needs to be implemented
        // once the penalty conditions and signature verification are finalized
    }

    function testInitiateExit() public {
        vm.startPrank(registrant);
        registry.register{value: 2 ether}();
        registry.initiateExit(1 ether);
        vm.stopPrank();

        PreconfirmationRegistry.Registrant memory info = registry.getRegistrantInfo(registrant);
        assertEq(info.balance, 2 ether);
        assertEq(info.exitInitiatedAt, block.number);
        assertEq(info.amountExiting, 1 ether);
    }

    function testWithdraw() public {
        vm.startPrank(registrant);
        registry.register{value: 2 ether}();
        registry.initiateExit(1 ether);
        vm.stopPrank();

        vm.roll(block.number + 33);

        uint256 balanceBefore = registrant.balance;
        vm.prank(registrant);
        registry.withdraw(registrant);

        assertEq(registrant.balance - balanceBefore, 1 ether);
    }

    function testMultipleDelegations() public {
        address proposer2 = vm.addr(3);
        vm.deal(registrant, 3 ether);
        
        vm.startPrank(registrant);
        registry.register{value: 3 ether}();
        
        address[] memory proposers = new address[](2);
        proposers[0] = proposer;
        proposers[1] = proposer2;
        registry.delegate(proposers);
        vm.stopPrank();

        PreconfirmationRegistry.Registrant memory registrantInfo = registry.getRegistrantInfo(registrant);
        PreconfirmationRegistry.Proposer memory proposerInfo1 = registry.getProposerInfo(proposer);
        PreconfirmationRegistry.Proposer memory proposerInfo2 = registry.getProposerInfo(proposer2);
        
        assertEq(registrantInfo.delegatedProposers.length, 2);
        assertEq(registrantInfo.delegatedProposers[0], proposer);
        assertEq(registrantInfo.delegatedProposers[1], proposer2);
        assertEq(proposerInfo1.delegatedBy.length, 1);
        assertEq(proposerInfo1.delegatedBy[0], registrant);
        assertEq(proposerInfo2.delegatedBy.length, 1);
        assertEq(proposerInfo2.delegatedBy[0], registrant);
    }

    function testUpdateStatusMultipleProposers() public {
        address proposer2 = vm.addr(3);
        vm.deal(registrant, 3 ether);
        
        vm.startPrank(registrant);
        registry.register{value: 3 ether}();
        
        address[] memory proposers = new address[](2);
        proposers[0] = proposer;
        proposers[1] = proposer2;
        registry.delegate(proposers);
        vm.stopPrank();

        vm.roll(block.number + 32);

        registry.updateStatus(proposers);

        assertEq(uint(registry.getProposerStatus(proposer)), uint(PreconfirmationRegistry.Status.PRECONFER));
        assertEq(uint(registry.getProposerStatus(proposer2)), uint(PreconfirmationRegistry.Status.PRECONFER));
        assertEq(registry.getEffectiveCollateral(proposer), 3 ether);
        assertEq(registry.getEffectiveCollateral(proposer2), 3 ether);
    }

    function testWithdrawToDifferentAddress() public {
        address withdrawAddress = vm.addr(3);
        
        vm.startPrank(registrant);
        registry.register{value: 2 ether}();
        registry.initiateExit(1 ether);
        vm.stopPrank();

        vm.roll(block.number + 33);

        uint256 balanceBefore = withdrawAddress.balance;
        vm.prank(registrant);
        registry.withdraw(withdrawAddress);

        assertEq(withdrawAddress.balance - balanceBefore, 1 ether);
    }

    function testInitiateExitInsufficientBalance() public {
        vm.startPrank(registrant);
        registry.register{value: 1 ether}();
        vm.expectRevert("Insufficient balance");
        registry.initiateExit(2 ether);
        vm.stopPrank();
    }
}