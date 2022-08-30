%lang starknet

@contract_interface
namespace IERC721:
    func balanceOf(owner : felt) -> (balance : felt):
    end

    func ownerOf(tokenId : felt) -> (owner : felt):
    end

    func safeTransferFrom(from_ : felt, to : felt, tokenId : felt, data_len : felt, data : felt*):
    end

    func transferFrom(from_ : felt, to : felt, tokenId : felt):
    end

    func approve(approved : felt, tokenId : felt):
    end

    func setApprovalForAll(operator : felt, approved : felt):
    end

    func getApproved(tokenId : felt) -> (approved : felt):
    end

    func isApprovedForAll(owner : felt, operator : felt) -> (isApproved : felt):
    end
end
