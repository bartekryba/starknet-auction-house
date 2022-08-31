%lang starknet

from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address

namespace erc20_helpers:
    func assert_address_balance(address: felt, balance: felt):
        %{
           stored = load(context.erc20_address, "ERC20_balances", "Uint256", key=[ids.address])
           as_int = stored[0] + stored[1]*2**128
           assert as_int == ids.balance, f"Address {ids.address} balance {as_int} != {ids.balance}"
        %}
        return ()
    end

    func assert_balance{syscall_ptr: felt*}(amount: felt):
        let (address) = get_caller_address()
        erc20_helpers.assert_address_balance(address, amount)
        return ()
    end


    func top_up_address{range_check_ptr}(address: felt, amount: felt):
        # Storage saves balance as Uint256, so we need to split our amount into two 128bit integers
        let (high, low) = split_felt(amount)
        %{ store(context.erc20_address, "ERC20_balances", [ids.low, ids.high], key=[ids.address]) %}
        return ()
    end

    func top_up{syscall_ptr: felt*, range_check_ptr}(amount: felt):
        let (address) = get_caller_address()
        erc20_helpers.top_up_address(address, amount)
        return ()
    end

    # Deploys ERC20 contract using deploy_contract cheatcode.
    # This takes a lot of time and should be done just once in __setup__ hook.
    # Deployed contract's address is stored in context available through hints.
    func deploy_contract():
        %{
            context.erc20_address = deploy_contract(
                "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo",
                [0, 0, 0, 0, 0, 1],
            ).contract_address
        %}
        return ()
    end

    # Returns address of contract deployed with deploy_contract
    func get_address() -> (address: felt):
        tempvar address
        %{ ids.address = context.erc20_address %}
        return (address)
    end
end