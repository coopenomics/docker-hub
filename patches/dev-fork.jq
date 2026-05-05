# Подменяет authority eosio@active|owner и producer schedule на dev-ключ,
# чтобы локальная нода могла продьюсить блоки с известным приватником.
#
# Dev keypair (Antelope default):
#   public:  EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV
#   private: 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3
#
# Использование:
#   ./scripts/fork-snapshot.sh --patch patches/dev-fork.jq --keep-json
# Перед прогоном на проде — посмотри сгенерённый snap.json, проверь имена
# секций (они зависят от версии coopos), при необходимости подкрути этот
# патч под реальную структуру.

# Целевой ключ
. as $root
| ($root | "EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV") as $DEV_KEY
| ({key: $DEV_KEY, weight: 1}) as $dev_key_weight

# 1. Подмена permission_object для системного аккаунта `eosio`.
#    Ищем все строки в секциях permission_object, у которых owner=="eosio".
#    Заменяем authority на single-key с порогом 1.
| (.sections[]?
    | select(.name | test("permission_object"; "i"))
    | .rows[]?
    | select(.data.owner == "eosio" or .data.owner == "0000000000ea3055")
   ) |= (
     .data.auth.threshold = 1
     | .data.auth.keys = [$dev_key_weight]
     | .data.auth.accounts = []
     | .data.auth.waits = []
   )

# 2. Подмена active producer schedule в global_property_object.
#    proposed_schedule заменяем на single producer "eosio" с dev_key.
| (.sections[]?
    | select(.name | test("global_property"; "i"))
    | .rows[]?
   ) |= (
     .data.proposed_schedule_block_num = 0
     | .data.proposed_schedule = {
         version: 0,
         producers: [
           { producer_name: "eosio", block_signing_key: $DEV_KEY }
         ]
       }
   )

# 3. Подмена active producer schedule в block_header_state (head block в снапшоте).
#    schedule.producers — массив, оставляем единственного "eosio" с dev_key.
| (.sections[]?
    | select(.name | test("block_state|block_header_state"; "i"))
    | .rows[]?
   ) |= (
     if .data.header_exts == null then . else . end
     | .data.active_schedule.producers = [
         { producer_name: "eosio", block_signing_key: $DEV_KEY }
       ]
     | .data.pending_schedule.schedule.producers = [
         { producer_name: "eosio", block_signing_key: $DEV_KEY }
       ]
   )
