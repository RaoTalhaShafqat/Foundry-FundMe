// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//This will be a little gas efficient contract based on teachings of Patrick Collins.
//So the purpose is to make sure people can fund this contract and the owner can withdraw those funds.
import {PriceConverter} from "./PriceConverter.sol";
import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error FundMe__insufficientFunds(); //We will use this to check the minimum USD requirements to be funded.
error FundMe__NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MIN_USD = 5e18;
    address[] private s_funders; //A list to track funders
    mapping(address => uint256) private s_addressToAmountFunded; //A map to get sender value from sender address.
    address private immutable contract_owner;
    AggregatorV3Interface private s_priceFeed;

    //This sets the owner at deployment time.
    //After that the owner is not changeable.
    constructor(address priceFeedAddress) {
        contract_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    //So payable allows us to the send the contract the desired funds.
    function fund() public payable {
        //So we use error to revert the transaction if if condition is satisfied.
        if (msg.value.getConversionRate(s_priceFeed) < MIN_USD) {
            revert FundMe__insufficientFunds();
        }

        s_addressToAmountFunded[msg.sender] += msg.value; //This will add the previous funds of the sender to their newly send funds.
        s_funders.push(msg.sender); //So we will add the address of sender to funders list.
    }

    //This part of the code does not contribute to the functionality of the contract but just a way to interact with the chainlink priceFeed.
    //This helps to cross check if the Aggregator is working properly.

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    //we need a helping function which can help us to check for owner before calling the withdraw function.
    modifier onlyOwner() {
        if (msg.sender != contract_owner) {
            revert FundMe__NotOwner();
        }
        _;
    }

    function withdrawFunds() public onlyOwner {
        //Now before withdrawing we need to empty the values of all the funders w.r.t their address.
        for (uint256 i = 0; i < s_funders.length; i++) {
            address funder = s_funders[i];
            s_addressToAmountFunded[funder] = 0;
        }

        //Here we clear out the list of funders
        s_funders = new address[](0);

        //Now we send the Eth to the owner of the contract
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!callSuccess) {
            revert("Failed to withdraw money");
        }
    }

    function cheaperWithdraw() public onlyOwner {
        //Now before withdrawing we need to empty the values of all the funders w.r.t their address.
        address[] memory funders = s_funders; //This will save the list of funders in memory and we can use it to loop through it and update the mapping. This is more gas efficient than using storage variable directly.
        for (uint256 i = 0; i < funders.length; i++) {
            address funder = funders[i];
            s_addressToAmountFunded[funder] = 0;
        }

        //Here we clear out the list of funders
        s_funders = new address[](0);

        //Now we send the Eth to the owner of the contract
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!callSuccess) {
            revert("Failed to withdraw money");
        }
    }

    //Now we need a logic for low level interactions for smartcontracts

    fallback() external payable {
        //In case someone sends also the data with txn.
        fund();
    }

    receive() external payable {
        //In cases of no Data with txn.
        fund();
    }

    //Now we will add some getter functions to get the private variables of the contract.
    function getAddressToAmountFunded(
        address funder
    ) external view returns (uint256) {
        return s_addressToAmountFunded[funder];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getContractOwner() external view returns (address) {
        return contract_owner;
    }
} //End of contract.
