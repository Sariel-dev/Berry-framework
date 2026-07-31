local Berry = exports["berry-core"]:GetCoreObject()

BerryEconomy = BerryEconomy or {}

function BerryEconomy.Transfer(source, targetSource, account, amount, reason)
    if not BerryTypes.IsPositiveNumber(amount) then
        return false, "Invalid amount."
    end

    local sender = Berry.GetPlayer(source)
    local receiver = Berry.GetPlayer(targetSource)

    if not sender then return false, "Sender not found." end
    if not receiver then return false, "Receiver not found." end

    account = account or "bank"
    reason = reason or "p2p_transfer"

    if sender:GetMoney(account) < amount then
        return false, "Insufficient funds."
    end

    if sender:RemoveMoney(account, amount, reason) then
        if receiver:AddMoney(account, amount, reason) then
            MySQL.insert.await([[
                INSERT INTO berry_transactions (source_id, target_id, amount, account_type, reason)
                VALUES (?, ?, ?, ?, ?)
            ]], { tostring(sender:GetCharacterId()), tostring(receiver:GetCharacterId()), amount, account, reason })

            Berry.Logger.Info("ECONOMY", "Transfer of %.2f (%s) from char %d to char %d succeeded.", amount, account, sender:GetCharacterId(), receiver:GetCharacterId())
            return true, "Transfer successful."
        else
            sender:AddMoney(account, amount, "transfer_rollback")
            return false, "Receiver transaction failed."
        end
    end

    return false, "Sender transaction failed."
end

Berry.Callbacks.Register("berry:economy:transfer", function(source, cb, targetSource, account, amount, reason)
    local success, msg = BerryEconomy.Transfer(source, targetSource, account, amount, reason)
    cb(success, msg)
end)
