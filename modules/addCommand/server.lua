---@class CommandParams
---@field name string
---@field help? string
---@field type? 'number' | 'playerId' | 'string'
---@field optional? boolean
---@field full? boolean

---@class CommandProperties
---@field help string?
---@field params CommandParams[]?
---@field restricted boolean | string | string[]?


---@type CommandProperties[]
local registeredCommands = {}
local shouldSendCommands = false

SetTimeout(1000, function()
   shouldSendCommands = true
   TriggerClientEvent('chat:addSuggestions', -1, registeredCommands)
end)

AddEventHandler('playerJoining', function(source)
   TriggerClientEvent('chat:addSuggestions', source, registeredCommands)
end)

---@param source number
---@param args table
---@param raw string
---@param params CommandParams[]?
---@return table?
local function parseArguments(source, args, raw, params)
   if not params then return args end

   for i = 1, #params do
      local arg, param = args[i], params[i]
      local value

      if param.type == 'number' then
         value = tonumber(arg)
      elseif param.type == 'string' then
         if param.full then
            value = raw:sub(#arg + 1)
         else
            value = not tonumber(arg) and arg
         end
      elseif param.type == 'playerId' then
         value = arg == 'me' and source or tonumber(arg)

         if not value or not DoesPlayerExist(value --[[@as string]]) then
            value = false
         end
      else
         value = arg
      end

      if not value and (not param.optional or param.optional and arg) then
         return Citizen.Trace(("^1command '%s' received an invalid %s for argument %s (%s), received '%s'^0\n"):format(
            string.strsplit(' ', raw) or raw, param.type, i, param.name, arg))
      end

      arg = value

      args[param.name] = arg
      args[i] = nil
   end

   return args
end

---@param commandName string | string[]
---@param properties CommandProperties | false
---@param cb fun(source: number, args: table, raw: string)
---@param ... any
function vx.addCommand(commandName, properties, cb, ...)
   local restricted, params

   if properties then
      restricted = properties.restricted
      params = properties.params
   end

   if params then
      for i = 1, #params do
         local param = params[i]

         if param.type then
            param.help = param.help and ('%s (type: %s)'):format(param.help, param.type) or
                ('(type: %s)'):format(param.type)
         end
      end
   end

   local commands = type(commandName) ~= 'table' and { commandName } or commandName
   local numCommands = #commands
   local totalCommands = #registeredCommands

   local function commandHandler(source, args, raw)
      args = parseArguments(source, args, raw, params)

      if not args then return end

      local success, resp = pcall(cb, source, args, raw)

      if not success then
         Citizen.Trace(("^1command '%s' failed to execute!\n%s"):format(string.strsplit(' ', raw) or raw, resp))
      end
   end

   for i = 1, numCommands do
      totalCommands += 1
      commandName = commands[i]

      RegisterCommand(commandName, commandHandler, restricted and true)

      if restricted then
         local ace = ('command.%s'):format(commandName)
         local restrictedType = type(restricted)

         if restrictedType == 'string' and not IsPrincipalAceAllowed(restricted, ace) then
            ExecuteCommand(('add_ace %s %s %s'):format(restricted, ace, "deny"))
         elseif restrictedType == 'table' then
            for j = 1, #restricted do
               if not IsPrincipalAceAllowed(restricted[j], ace) then
                  ExecuteCommand(('add_ace %s %s %s'):format(restricted[j], ace, "deny"))
               end
            end
         end
      end

      if properties then
         properties.name = ('/%s'):format(commandName)
         properties.restricted = nil
         registeredCommands[totalCommands] = properties

         if i ~= numCommands and numCommands ~= 1 then
            properties = table.clone(properties)
         end

         if shouldSendCommands then TriggerClientEvent('chat:addSuggestions', -1, properties) end
      end
   end
end

return vx.addCommand
