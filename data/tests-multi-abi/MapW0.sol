pragma solidity 0.7.6;

interface MappingFunction {
    function execute() external returns (uint256);
}

contract Array {
    address owner = msg.sender;
    mapping(uint256 => uint256) a;

    function get(uint256 i) public view returns (uint256) {
        return a[i];
    }

    function set(uint256 i, uint256 v) public {
        a[i] = v;
    }
}

contract Map {
    Array mappings = new Array();

    event AssertionFailed();

    function getOrCompute(uint256 k, MappingFunction computeF)
        public
        returns (uint256)
    {
        uint256 i = getIndex(k);
        uint256 v = 0;
        if (!isMapped(i)) {
            // compute the value
            v = computeF.execute();
            require(v != 0);
            // assume that isMapped is still not true
            if (isMapped(i)) {
                emit AssertionFailed();
                selfdestruct(payable(msg.sender));
            }
            // set the mapping
            mappings.set(i, v);
        }
        return mappings.get(i);
    }

    function getIndex(uint256 k) private view returns (uint256) {
        return k;
    }

    function isMapped(uint256 i) private view returns (bool) {
        return mappings.get(i) != 0;
    }
}
