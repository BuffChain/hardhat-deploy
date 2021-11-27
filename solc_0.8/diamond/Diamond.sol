// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import { LibDiamond } from "./libraries/LibDiamond.sol";
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "./interfaces/IDiamondLoupe.sol";
import { IERC173 } from "./interfaces/IERC173.sol";
import { IERC165 } from "./interfaces/IERC165.sol";

import { console } from "hardhat/console.sol";

contract Diamond {
    // more arguments are added to this struct
    // this avoids stack too deep errors
    struct DiamondArgs {
        address owner;
    }

    constructor(IDiamondCut.FacetCut[] memory _diamondCut, DiamondArgs memory _args) payable {
        console.log("---------");
        console.log("Diamond");
        console.log("---------");

        LibDiamond.diamondCut(_diamondCut, address(0), new bytes(0));
        LibDiamond.setContractOwner(_args.owner);

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // adding ERC165 data
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");

        console.log("---------");
        console.log("FACET [%s]", facet);
//        console.log("position [%i]", position);
        console.log("---------");

        uint256 result;

        // Execute external function from facet using delegatecall and return any value.
        assembly {
            let callMem := mload(0x40)

            // copy function selector and any arguments
            calldatacopy(callMem, 0, calldatasize())
            // execute function call using the facet
            result := delegatecall(gas(), facet, callMem, calldatasize(), 0, 0)

            let returnMem := mload(0x40)
            // get any return value
            returndatacopy(returnMem, 0, returndatasize())

            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(returnMem, returndatasize())
                }
                default {
                    return(returnMem, returndatasize())
                }
        }
    }

    receive() external payable {}
}
