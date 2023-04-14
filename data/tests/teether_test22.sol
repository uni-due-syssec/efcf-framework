pragma solidity 0.7.6;

contract TeetherTest22 {
    mapping(bytes32 => uint256) approved;

    function pay(
        address to,
        uint256 amount,
        uint256 secret
    ) public {
        require(secret != 0);
        bytes32 key = keccak256(msg.data);
        if (approved[key] == secret) {
            payable(to).transfer(amount);
        } else {
            approved[key] = secret;
        }
    }
}
