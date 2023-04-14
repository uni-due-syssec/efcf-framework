pragma solidity 0.7.6;

contract MultiOwned {
    // pointer used to find a free slot in m_owners
    uint256 public m_numOwners;

    // the number of owners that must confirm the same operation before it is run.
    uint256 public m_required;

    // list of owners
    address[256] m_owners;

    // index on the list of owners to allow reverse lookup
    mapping(address => uint256) m_ownerIndex;

    // the ongoing operations.
    mapping(bytes32 => PendingState) m_pending;
    bytes32[] m_pendingIndex;

    // struct for the status of a pending operation.
    struct PendingState {
        uint256 yetNeeded;
        uint256 ownersDone;
        uint256 index;
    }

    // simple single-sig function modifier.
    modifier onlyowner() {
        if (isOwner(msg.sender)) _;
    }

    modifier onlymanyowners(bytes32 _operation) {
        require(confirmAndCheck(_operation));
        _;
    }

    // constructor is given number of sigs required to do protected "onlymanyowners" transactions
    // as well as the selection of addresses capable of confirming them.
    function initMultiowned(address[] memory _owners, uint256 _required)
        public
    {
        m_numOwners = _owners.length + 1;
        m_owners[1] = msg.sender;
        m_ownerIndex[msg.sender] = 1;
        for (uint256 i = 0; i < _owners.length; ++i) {
            m_owners[2 + i] = _owners[i];
            m_ownerIndex[_owners[i]] = 2 + i;
        }
        m_required = _required;
    }

    function isOwner(address _addr) public view returns (bool) {
        return m_ownerIndex[_addr] > 0;
    }

    function confirmAndCheck(bytes32 _operation) internal returns (bool) {
        // determine what index the present sender is:
        uint256 ownerIndex = m_ownerIndex[msg.sender];
        // make sure they're an owner
        if (ownerIndex == 0) {
            return false;
        }

        PendingState storage pending = m_pending[_operation];
        // if we're not yet working on this operation, switch over and reset the confirmation status.
        if (pending.yetNeeded == 0) {
            // reset count of confirmations needed.
            pending.yetNeeded = m_required;
            // reset which owners have confirmed (none) - set our bitmap to 0.
            pending.ownersDone = 0;
            pending.index = m_pendingIndex.length + 1;
            m_pendingIndex.push(_operation);
        }
        // determine the bit to set for this owner.
        uint256 ownerIndexBit = 2**ownerIndex;
        // make sure we (the message sender) haven't confirmed this operation previously.
        if (pending.ownersDone & ownerIndexBit == 0) {
            // ok - check if count is enough to go ahead.
            if (pending.yetNeeded <= 1) {
                // enough confirmations: reset and run interior.
                delete m_pendingIndex[m_pending[_operation].index];
                delete m_pending[_operation];
                return true;
            } else {
                // not enough: record that this owner in particular confirmed.
                pending.yetNeeded--;
                pending.ownersDone |= ownerIndexBit;
            }
        }

        return false;
    }
}

contract TeetherTest14Multiowned is MultiOwned {
    function pay(address to, uint256 amount)
        public
        onlymanyowners(keccak256(msg.data))
    {
        payable(to).transfer(amount);
    }
}
