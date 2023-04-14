pragma solidity 0.7.6;

contract Calldata3 {
    function deposit() public payable {}

    function solve(bytes calldata input) public {
        bytes memory byteInput = bytes(input);
        if (
            byteInput[0] == "A" &&
            byteInput[1] == "B" &&
            byteInput[2] == "C" &&
            byteInput[3] == "D" &&
            byteInput[4] == "E" &&
            byteInput[5] == "F" &&
            byteInput[6] == "G" &&
            byteInput[7] == "H" &&
            byteInput[8] == "I" &&
            byteInput[9] == "J" &&
            byteInput[10] == "K" &&
            byteInput[11] == "L" &&
            byteInput[18] == "l" &&
            byteInput[19] == "m" &&
            byteInput[20] == "\x00" &&
            byteInput[21] == "\x01" &&
            byteInput[22] == "\x02" &&
            byteInput[23] == "\xFF" &&
            byteInput[128] == "\x01" &&
            byteInput[129] == byteInput[128] &&
            byteInput[130] == byteInput[129] &&
            byteInput[131] == byteInput[130] &&
            byteInput[132] == byteInput[131] &&
            byteInput[510] == "E" &&
            byteInput[511] == "N" &&
            byteInput[512] == "D"
        ) {
            selfdestruct(msg.sender);
        }
    }
}
