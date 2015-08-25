local socket = require('socket')
local epoll = require('epoll')
local sched = require('sched')

local M = {}

function M.qpoll(s, cb) -- "quittable" poll
   local sp_recv, sp_send = socket.socketpair(socket.PF_LOCAL, socket.SOCK_STREAM)
   local poller = epoll.create(2)
   poller:add(sp_recv.fd, "r", sp_recv.fd)
   poller:add(s.fd, "r", s.fd)
   sched.on('quit', function()
      sp_send:write("stop\n")
      local reply = sp_send:readline()
      if reply ~= "stopped" then
         error("invalid reply to stop request")
      end
      sp_send:close()
   end)
   local running = true
   while running do
      sched.poll(poller.fd, "r")
      poller:wait(0, function(events, fd)
         if fd == s.fd then
            cb(s)
         elseif fd == sp_recv.fd then
            sp_recv:write("stopped\n")
            running = false
         end
      end)
   end
   poller:del(s.fd, "r", s.fd)
   poller:del(sp_recv.fd, "r", sp_recv.fd)
   poller:close()
   sp_recv:close()
end

return M
