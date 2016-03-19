/*Most, basic default, standardised Token contract.
Allows the creation of a token with a finite issued amount to the creator.

Implements ERC 20 Token standard: https://github.com/ethereum/EIPs/issues/20
.*/

import "Token.sol";

contract Destiny is Token {

    struct DepositInfo{
      uint256 value;
      uint256 period;
      uint256 creationTime;
    }

    function Destiny() {
        COIN = 100000000;
        balances[msg.sender] = 2100000 * COIN;
        totalSupply = 2100000 * COIN;
        totalBurnt = 0;
        totalDeposited = 0;
        baseUnit = COIN;
    }

    function () {
        //if ether is sent to this address, send it back.
        throw;
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    //NOTE: This function will throw errors wrt changing storage where it should not, due to the optimizer errors, IF not careful.
    //As it is now, it works for both earlier and newer solc versions. (NO need to change anything)
    //In the future, the TransferFrom event will be moved to just before "return true;" in order to make it more elegant (once the new solc version is out of develop).
    //If you want to move parts of this function around and it breaks, you'll need at least:
    //Over commit: https://github.com/ethereum/solidity/commit/67c855c583042ddee6261a9921239a3afd086c14 (last successfully working commit)
    //See issue for details: https://github.com/ethereum/solidity/issues/333 & issue: https://github.com/ethereum/solidity/issues/281
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            Transfer(_from, _to, _value);
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function burn(uint256 _value) returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            Transfer(msg.sender, 0, _value);
            totalSupply -= _value;
            totalBurnt += _value;
            return true;
        } else { return false; }
    }

    event Deposit(address indexed _owner, uint256 _value, uint256 _period);
    event CheckOut(address indexed _owner, uint256 _value);

    function deposit(uint256 _value, uint256 _period) returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0 && deposits[msg.sender].value == 0 && _period > 0) {
            balances[msg.sender] -= _value;
            Deposit(msg.sender, _value, _period);
            totalDeposited += _value;
            deposits[msg.sender] = DepositInfo(_value, _period, now);
            return true;
        } else { return false; }
    }

    // Returns rate in tenth of percent
    function interest(uint256 _value, uint256 _period) returns (uint rate){
        if (_value > 50000 * COIN) {
            if (_period < 30 days) {
                return 10;
            } else if (_period < 90 days) {
                return 50;
            } else if (_period < 180 days) {
                return 100;
            } else if (_period < 1 years) {
                return 150;
            } else {
                return 200;
            }
        } else {
            if (_period < 30 days) {
                return 1;
            } else if (_period < 90 days) {
                return 30;
            } else if (_period < 180 days) {
                return 60;
            } else if (_period < 1 years) {
                return 90;
            } else {
                return 120;
            }
        }
    }

    function cashOut() returns (bool success) {
        if (deposits[msg.sender].value == 0) {
            return false;
        } else {
            if (now > deposits[msg.sender].creationTime + deposits[msg.sender].period) {
                var intrst = interest(deposits[msg.sender].value, deposits[msg.sender].period);
                var profit = deposits[msg.sender].value * intrst * deposits[msg.sender].period / (1 years) / 1000;

                balances[msg.sender] += deposits[msg.sender].value + profit;
                totalSupply += profit;

                CheckOut(msg.sender, deposits[msg.sender].value + profit);
            } else {
                var loss = deposits[msg.sender].value * 3 / 100;

                balances[msg.sender] += deposits[msg.sender].value - loss;
                totalSupply -= loss;

                CheckOut(msg.sender, deposits[msg.sender].value - loss);
            }

            totalDeposited -= deposits[msg.sender].value;
            deposits[msg.sender] = DepositInfo(0,0,0);

        }
        return true;
    }

    function checkDeposit() constant returns (bool success, uint256 value, uint256 remainingTime, uint256 rate) {
        if (deposits[msg.sender].value == 0) {
            return (false, 0, 0, 0);
        } else {
            var time = deposits[msg.sender].period - (now - deposits[msg.sender].creationTime);

            if (time > 0) {
                return (true, deposits[msg.sender].value,  time, interest(deposits[msg.sender].value, deposits[msg.sender].period));
            } else {
                return (true, deposits[msg.sender].value,  0, interest(deposits[msg.sender].value, deposits[msg.sender].period));
            }
        }
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    mapping (address => DepositInfo) deposits;
    uint256 public totalSupply;
    uint256 public totalBurnt;
    uint256 public totalDeposited;
    uint256 public COIN;
    uint256 public baseUnit;
}
