contract ExchangeFactory {
    function getExchange(address token) public view returns (address) {
        if (token == address(0x3212b29E33587A00FB1C83346f5dBFA69A458923)) {
            return address(0x74Ba118A0F49C391Ce0fdeE0F77119cB009d8971);
        } else {
            return address(0);
        }
    }
}
