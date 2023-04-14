pragma solidity 0.7.6;
pragma abicoder v2;

contract selfcallloop {

    // implicit invariant that this contract never has a Ether balance (i.e.,
    // it either returns the Ether or reverts)

    uint S = 0;
    function one(uint i) public payable {
        assert(i >= msg.value);
        S += i - msg.value;
        msg.sender.transfer(msg.value);
    }

    uint V;
    function two(uint i, uint j) public {
        V = i + j;
    }

    receive() external payable {
        assert(msg.value == 0);
    }

    function multiListingFill(
        bytes[] calldata data,
        uint256[] calldata values,
        bool revertIfIncomplete
    ) external payable {
        bool success;
        for (uint256 i = 0; i < data.length; i++) {
            (success, ) = address(this).call{value: values[i]}(data[i]);
            if (revertIfIncomplete) {
                require(success, "Atomic fill failed");
            }
        }

        (success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Could not send payment");
    }
}
