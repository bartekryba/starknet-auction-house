%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.asset_vault.library import AssetVault

@view
func get_erc721_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    let (address) = AssetVault.get_erc721_address()

    return (address)
end

@view
func get_asset_status{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset_id : felt
) -> (asset_status : felt):
    let (status) = AssetVault.get_asset_status(asset_id)

    return (status)
end

@external
func deposit_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset_id : felt
):
    AssetVault.deposit_asset(asset_id)

    return ()
end

@external
func withdraw_asset{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset_id : felt
):
    AssetVault.withdraw_asset(asset_id)

    return ()
end
