// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

abstract contract Ownable is Context {
    address private _owner;
    address public pendingOwner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        _owner = address(0);
        pendingOwner = address(0);
        emit OwnershipTransferred(_owner, address(0));
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(address(0) != newOwner, "pendingOwner set to the zero address.");
        pendingOwner = newOwner;
    }

    function claimOwnership() public {
        require(msg.sender == pendingOwner, "caller != pending owner");

        _owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(_owner, pendingOwner);
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) internal _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

abstract contract ERC20Burnable is Context, ERC20, Ownable {
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
    unchecked {
        _approve(account, _msgSender(), currentAllowance - amount);
    }
        _burn(account, amount);
    }
}

abstract contract ERC20Lockable is ERC20, Ownable {
    struct LockInfo {
        uint256 _releaseTime;
        uint256 _amount;
    }

    mapping(address => LockInfo[]) internal _locks;
    mapping(address => uint256) internal _totalLocked;

    event Lock(address indexed from, uint256 amount, uint256 releaseTime);
    event Unlock(address indexed from, uint256 amount);

    /**
     * Modifier to check whether there is sufficient balance by checking the amount locked at the address.
     */
    modifier checkLock(address from, uint256 amount) {
        uint256 length = _locks[from].length;
        if (length > 0) {
            autoUnlock(from);
        }
        require(_balances[from] >= _totalLocked[from] + amount, "checkLock : balance exceed");
        _;
    }

    /**
     * funcion lock.
     */
    function _lock(address from, uint256 amount, uint256 releaseTime) checkLock(from, amount) internal returns (bool success)
    {
        require(
            _balances[from] >= amount + _totalLocked[from],
            "lock : locked total should be smaller than balance"
        );
        _totalLocked[from] = _totalLocked[from] + amount;
        _locks[from].push(LockInfo(releaseTime, amount));
        emit Lock(from, amount, releaseTime);
        success = true;
    }

    /**
     * funcion unlock.
     */
    function _unlock(address from, uint256 index) internal returns (bool success) {
        LockInfo storage info = _locks[from][index];
        _totalLocked[from] = _totalLocked[from] - info._amount;
        emit Unlock(from, info._amount);
        _locks[from][index] = _locks[from][_locks[from].length - 1];
        _locks[from].pop();
        success = true;
    }

    /**
     * Specify lock amount until specified release time.
     */
    function lock(address recipient, uint256 amount, uint256 releaseTime) public onlyOwner returns (bool success) {
        require(_balances[recipient] >= amount, "There is not enough balance of holder.");
        _lock(recipient, amount, releaseTime);

        success = true;
    }

    /**
     * Unlock the lock past the release time.
     */
    function autoUnlock(address from) public returns (bool success) {
        for (uint256 i = 0; i < _locks[from].length; i++) {
            if (_locks[from][i]._releaseTime < block.timestamp) {
                _unlock(from, i);
            }
        }
        success = true;
    }

    /**
     * Unlock the specific lock of the address.
     */
    function unlock(address from, uint256 idx) public onlyOwner returns (bool success) {
        require(_locks[from].length > idx, "There is not lock info.");
        _unlock(from, idx);
        success = true;
    }

    /**
     * Unlock all locks in address.
     */
    function releaseLock(address from) external onlyOwner returns (bool success){
        require(_locks[from].length > 0, "There is not lock info.");
        for (uint256 i = _locks[from].length; i > 0; i--) {
            _unlock(from, i - 1);
        }
        success = true;
    }

    /**
     * After transfer, lock the amount until a specific release time.
     */
    function transferWithLock(address recipient, uint256 amount, uint256 releaseTime) external onlyOwner returns (bool success)
    {
        require(recipient != address(0));
        _transfer(msg.sender, recipient, amount);
        _lock(recipient, amount, releaseTime);
        success = true;
    }

    /**
     * Check lock information.
     */
    function lockInfo(address locked, uint256 index) public view returns (uint256 releaseTime, uint256 amount)
    {
        LockInfo memory info = _locks[locked][index];
        releaseTime = info._releaseTime;
        amount = info._amount;
    }

    /**
     * Check the total lock amount and count of address.
     */
    function totalLocked(address locked) public view returns (uint256 amount, uint256 length){
        amount = _totalLocked[locked];
        length = _locks[locked].length;
    }
}

contract Pausable is Ownable {
    event Pause();
    event Unpause();
    event PauserChanged(address indexed newAddress);

    address public pauser;
    bool public paused = false;

    /**
     * Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    /**
     * throws if called by any account other than the pauser
     */
    modifier onlyPauser() {
        require(msg.sender == pauser, "Pausable: caller is not the pauser");
        _;
    }

    /**
     * called by the owner to pause, triggers stopped state
     */
    function pause() external onlyPauser {
        paused = true;
        emit Pause();
    }

    /**
     * called by the owner to unpause, returns to normal state
     */
    function unpause() external onlyPauser {
        paused = false;
        emit Unpause();
    }

    /**
     * Updates the pauser address.
     * _newPauser The address of the new pauser.
     */
    function updatePauser(address _newPauser) external onlyOwner {
        require(
            _newPauser != address(0),
            "Pausable: new pauser is the zero address"
        );
        pauser = _newPauser;
        emit PauserChanged(pauser);
    }
}

abstract contract ERC20Capped is ERC20 {
    uint256 private _cap;

    /**
     * @dev Total supply cap has been exceeded.
     */
    error ERC20ExceededCap(uint256 increasedSupply, uint256 cap);

    /**
     * @dev The supplied cap is not a valid cap.
     */
    error ERC20InvalidCap(uint256 cap);

    /**
     * @dev Sets the value of the `cap`.
     */
    constructor(uint256 cap_) {
        if (cap_ == 0) {
            revert ERC20InvalidCap(0);
        }
        _cap = cap_;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    /**
     * @dev See {ERC20-_update}.
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);

        if (from == address(0)) {
            uint256 maxSupply = cap();
            uint256 supply = totalSupply();
            if (supply > maxSupply) {
                revert ERC20ExceededCap(supply, maxSupply);
            }
        }
        if (to == address(0)) {
            unchecked {
            // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _cap -= value;
            }
        }
    }
}

contract LIX is ERC20, ERC20Burnable, ERC20Lockable, Pausable, ERC20Capped {

    constructor() ERC20("LIX", "LIX") ERC20Capped(10_000_000_000 * (10 ** decimals())) {
    }

    function transfer(address to, uint256 amount) public checkLock(msg.sender, amount) whenNotPaused() override returns (bool) {
        return super.transfer(to, amount);
    }

    // To transfer tokens to the provided list of address with respective amount
    function batchTransfer(address[] calldata toAddresses, uint256[] calldata amounts) public 
    {
        require(toAddresses.length == amounts.length, "Invalid input parameters");

        for(uint256 indx = 0; indx < toAddresses.length; indx++) {
            require(transfer(toAddresses[indx], amounts[indx]), "Unable to transfer token to the account");
        }
    }

    function transferFrom(address from, address to, uint256 amount) public checkLock(from, amount) whenNotPaused() override returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }
    
    function burn(uint256 amount) public checkLock(msg.sender, amount) whenNotPaused() override {
        return super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public checkLock(account, amount) whenNotPaused() override {
        return super.burnFrom(account, amount);
    }

    function balanceOf(address holder) public view override returns (uint256 balance) {
        balance = super.balanceOf(holder);
    }

    function getAvailableBalance(address holder) public view override returns (uint256 balance) {
        uint256 totalBalance = super.balanceOf(holder);
        uint256 availableBalance = 0;
        (uint256 lockedBalance, uint256 lockedLength) = totalLocked(holder);
        require(totalBalance >= lockedBalance);

        if (lockedLength > 0) {
            for (uint i = 0; i < lockedLength; i++) {
                (uint256 releaseTime, uint256 amount) = lockInfo(holder, i);
                if (releaseTime <= block.timestamp) {
                    availableBalance += amount;
                }
            }
        }

        balance = totalBalance - lockedBalance + availableBalance;
    }

    function getLockAmount(address holder) public view returns (uint256 balance) {
        (uint256 lockedBalance, uint256 lockedLength) = totalLocked(holder);
        balance = lockedBalance;
    }

    function balanceOfTotal(address holder) public view returns (uint256 balance) {
        balance = super.balanceOf(holder);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped)
    {
        super._update(from, to, value);
    }
}