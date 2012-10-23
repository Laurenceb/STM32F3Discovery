define flash
file main.elf
load
end

define reconnect
target extended-remote localhost:4242
file main.elf
end

reconnect

