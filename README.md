# 3ds-toolchain
An N3DS toolchain targeting VSCode + WSL2 running Ubuntu 20.04 LTS. It also contains settings for dseight's *Disassembly Explorer* extension.

## Project Structure
- Build scripts are housed within the `build_scripts` directory. They can call each-other.
- Build logs are output to the `build_logs` directory when applicable.
- VSCode settings are tailored for 3DS development.
- `tasks.json` contains various tasks that can be run from the command palette.
- `launch.json` contains GDB remote debug launch setups.
- `settings.json` and `c_cpp_properties.json` contain various project settings.

## How To Use
- Launch GDB debugger sessions from the Run and Debug menu.
- Run the default build task with `ctrl` + `shift` + `b` or execute others from the command palette at the top of the window.
