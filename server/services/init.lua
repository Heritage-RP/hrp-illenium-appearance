--[[
    Services Module - Dependency Injection Container
    Following SOLID principles:
    - D: Dependency Inversion - Services are injected rather than directly referenced
]]

Services = Services or {}

-- Service registry for dependency injection
local serviceRegistry = {}

---Register a service
---@param name string Service identifier
---@param service table|function Service implementation
function Services.Register(name, service)
    serviceRegistry[name] = service
end

---Get a registered service
---@param name string Service identifier
---@return table|function|nil
function Services.Get(name)
    return serviceRegistry[name]
end

---Check if a service is registered
---@param name string Service identifier
---@return boolean
function Services.Has(name)
    return serviceRegistry[name] ~= nil
end

return Services
