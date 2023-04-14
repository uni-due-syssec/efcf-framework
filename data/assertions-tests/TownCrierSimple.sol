pragma solidity 0.7.6;

interface Callback {
    function call(bytes calldata data) external;
}

contract TownCrierSimple {
    address payable requester;
    Callback callback;
    uint public constant MIN_FEE = 1000;
    uint paid_fee = 0;
    // FUZZ: we use a fuzzer-controlled SGX_ADDR
    address SGX_ADDR = address(0x00c04689c0c5d48cec7275152b3026b53f6f78d03d);
    // FUZZ: fees are sent to a non-fuzzer controlled address
    address payable SGX_FEE_ADDR = address(0x00cf7c6611373327e75f8ef1beef8227afb89816dd);

    function request(address cb) public payable {
        uint paid = msg.value;
        require(msg.value >= MIN_FEE);
        require(requester == address(0));
        paid_fee = msg.value;
    	requester = payable(msg.sender);
    	callback = Callback(cb);
    }

    event AssertionFailed();

    function deliver(bytes memory data) public {
        require(msg.sender == SGX_ADDR);
        require(requester != address(0));

        callback.call(data);

        requester = address(0);
        // FUZZ: custom bug oracle
        if (address(this).balance < paid_fee) {
            emit AssertionFailed();
        } else {
            // FUZZ: only conditionally call transfer, otherwise it will revert
            // the deliver transaction, including the reentrant call to cancel.
            SGX_FEE_ADDR.transfer(paid_fee);
        }
    }

    function cancel() public {
        require(msg.sender == requester);
        requester = address(0);
        requester.transfer(paid_fee);
    }
}
