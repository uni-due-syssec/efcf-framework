pragma solidity 0.7.6;

contract Array {
    mapping(uint=>uint) a;

    function get(uint i) public view returns(uint) {
        return a[i];
    }

    function set(uint i, uint v) public {
        a[i] = v;
    }
}

interface MappingFunction {
    function execute() external returns(uint);
}

contract Map {
    Array mappings;

    function getOrCompute(uint k, MappingFunction computeF) public returns(uint) {
        uint i = getIndex(k);
        if (isMapped(i)) {
            uint v = computeF.execute();
            mappings.set(i, v);
        }
        return mappings.get(i);
    }

    function clear() public {
        // ...
    }

    function getIndex(uint k) private returns(uint) {
        return 0;
    }

    function isMapped(uint i) private returns(bool) {
        return true;
    }
}
