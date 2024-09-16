# 3DS Development Resources
Written by [Wyatt-James](https://github.com/Wyatt-James/)
The latest version can be found [here.](https://github.com/Wyatt-James/3ds-resources) You are currently reading version `1.1` published on `September 16, 2024.`

This is a document containing various bits of knowledge and resources for 3DS development. I gained this knowledge through research and experimentation, and I cannot stress how important the latter is. Take some code, tinker with it, and see where you end up.

All of the resources and information provided are publicly available.

Links can be found at the bottom of this document.

I do not own any trademarks mentioned herein.

Thank you to the DevkitPro team and all who have contributed to the various 3DS development resources, and of course the Big N for designing and manufacturing these excellent little rectangles.

## Development and Building

For development, use DevkitPro's open-source libraries and toolset.

You can use any IDE you want, but I use VSCode + WSL2 + Docker.
- VSCode supports C pretty well and supports cross-platform development very well via script tasks. It also has a good debugger and supports Git.
- WSL2 allows building from a Linux environment, which I generally prefer when targeting consoles.
- Docker enables consistent and repeatable builds, ensuring that players use the correct build tools and obtain consistent results.

For building, I use GNU Make.

## Running

To send the compiled file to your 3DS, you can either:
1. build and install a CIA (very slow; only use when testing CIA-specific features)
2. build a 3DSX, copy it to your SD card, and run it from the homebrew channel
3. build a 3DSX, use FTPD to copy it to your SD card wirelessly, and run it from the homebrew channel
4. build a 3DSX and use 3dslink to send it remotely to your 3DS

The best method of these is, of course, #4. It reduces the time to run your compiled code to about ten seconds and does not wear down your console mechanically. Sometimes, at the start of the day, it takes a few attempts to get my PC to recognize the 3DS.

The 3DS may hang when running your application for any number of reasons, such as exceptions, infinite loops, GPU hangs, etc. Holding the power button for several seconds will consistently power it down. Sometimes, the Rosalina menu's restart and shutdown commands may also work.

## Debugging

For debugging, the 3DS supports fairly robust remote attachment via GDB. Here are some things to keep in mind:
1. Sometimes, GDB's performance will suffer HEAVILY if the 3DS application is running in multi-threaded mode with a high AppCpuTimeLimit (see below). The impact varies based on many factors, including your local network, but running the application without CPU1 improves the issue.
2. The debugger requires wi-fi to be enabled and connected.
3. The debugger must be enabled for a specific process. The best way to do this is to open the Rosalina menu, select "Debugger options...," enable the debugger, and then enable "Force-debug next application at launch." You must repeat that last step every time you relaunch your application, and of course you should only ever do these steps from within the Homebrew Launcher.
4. A debugging-enabled application will hang on a black screen at launch if the debugger fails to connect. If you see this, you can disable the debugger from the Rosalina menu or attach with GDB to unfreeze it.
5. The debugger does not always exit cleanly. I find it generally consistent enough, but sometimes VSCode fails to close the debugging session. Disconnecting manually in VSCode fixes the issue. On rare occasions, the 3DS may hang.
6. Breakpoints, watches, etc. can only be modified when the application is paused.
7. Conditional breakpoints are extremely slow. Use separate code paths instead.
8. The crash handler is disabled when the debugger is active, as GDB will break instead, allowing you to see the cause.

The 3DS supports hardware watches.

## libctru

libctru is a library provided by DevkitPro that enables user-mode application development on the 3DS. There is full documentaion provided by DevkitPro, and the source files also often contain very useful information.

libctru will handle basically everything, and it does a very good job. However, due to the way its headers are defined, game ports from other systems will often suffer from bad type name collisions. Special guards should be put in-place whenever libctru files are included, as such:

```
#define u32 __3ds_u32
#include <3ds/types.h>
#include <3ds/something.h>
#undef u32
```

This code will remap `u32` to `__3ds_u32` to avoid name collisions. It sucks but it is what it is. I just use C standard types instead, casting to `__3ds_` types when necessary.

## Citro3D

Citro3D is a graphics library provided by DevkitPro. DevkitPro also provides a 2D version called Citro2D.

This is a fast stateful graphics library that wraps libctru's basic GPU driver, providing an OpenGL-esque interface. It is generally easy-to-use, but documentation is currently poor. A work-in-progress documentation fork exists, but it has not been merged yet. Looking at Citro3D's and libctru's code together will often prove very fruitful in understanding what's actually going on.

It is worth noting that it is possible to use libctru's GPU driver directly, and it would likely even improve performance significantly in emulation, but it would be a gigantic pain.

Citro3D uses a very particular frame generation logic loop:
1. System and Game logic run.
2. The game calls C3D_FrameBegin.
   - The main thread is stalled until the GPU command queue is free.
   - "Vsync" is provided. It isn't a true vsync, which is essentially impossible on 3DS, but instead a simple frame rate limiter. It is, however, tied to the display vertical blank and thus will not drift out of sync.
3. The game produces GPU commands (via C3D calls), which fill a finite queue.
4. The game calls C3D_FrameEnd.
   - The command queue is passed to the GPU and rendering begins.

Additionally, the framebuffer-to-screen swap is handled asynchronously once the command queue has been fully consumed. This causes poor frame pacing when targeting framerates under 60, depending on how long the CPU and GPU took to finish.

## The CPU and Memory

The CPU is an ARM11MPCore, featuring two identical CPU cores running at 268MHz. The CPU implements the ARMv6k architecture with some extensions, such as a VPU for floating-point math. These cores each have a small L1 cache, with separate data and instruction caches. Cache coherency is guaranteed by a snoop control unit. The 3DS features 128MB of general-purpose memory, though 64MB is reserved for the OS. A special mode can be specified in the CIA file granting 96MB to the game, with some caveats.

The New 3DS features four cores running at 804MHz, with an L2 cache shared by all cores. It also faetures 256MB of main memory, with 124/176 available to the game via the same mechanisms as the old 3DS.

This is a 32-bit CPU with a 64-bit data bus and some 64-bit instructions. The VPU also supports 32-bit and 64-bit floats. Other notable features include:
- Dynamic branch prediction
- An 8-stage pipeline
- Conditional execution on all instructions (most architectures only provide conditional branching)
- A small set of narrow SIMD instructions with 32-bit width, allowing for 2x16 or 4x8 operations.
- A set of media instructions, such as saturating arithmetic and multiply-accumulate.

The CPU is generally going to be the main bottleneck when developing emulation software, at least on the old 3DS. It's telling that the main focus of the New 3DS was improving the CPU and adding memory, while the GPU was left nearly unchanged.

## The Multi-Threading Model

The 3DS multi-threading model is weird. CPU0 is wholly owned by the game, and CPU1 is, by default, wholly owned by the OS. However, the game can request up to 80% of CPU1's time, allowing threads to be scheduled there, albeit with reduced performance.

On New 3DS, one of the new cores is wholly owned by the game, while one is available only to the OS.

Unfortunately, high AppCpuTimeLimit values can cause some OS tasks to slow down tremendously. For example, DSP_FlushDataCache runs in a consistent 0.1ms when single-threaded, but takes 1-5ms (avg 2.5ms) when multi-threading is enabled. In this case, svcFlushProcessDataCache provided a perfect alternative, giving fast performance at all times. Basically, if the performance of some syscalls feels off, there may be an alternative that will perform much better.

AppCpuTimeLimit only affects time allocation on CPU1, while CPU0 and New-3DS-exclusive CPU2 and CPU3 are unaffected.

The 3DS operating system schedules threads in a FIFO manner, meaning that poor programming can hang applications where a traditional OS scheduler may eventually break free.

## The DSP

The 3DS features a programmable hardware DSP capable of producing high-quality two-channel audio with various effects. A DSP firmware must be loaded by the game; while it is possible to program the DSP, this is fairly undocumented, so homebrew generally uses the stock firmware bundled with the 3DS system firmware.

The DSP supports raw PCM data and ADPCM-encoded data, though it should be noted that not all ADPCM formats are identical. Individual DSP channels can carry monaural or interleaved-stereo sample data.

## The GPU

The GPU features fully programmable vertex and geometry shaders and a fixed-function fragment (pixel) pipeline. Vertex and geometry shaders are programmed in a bespoke assembly language and compiled by Picasso (see below). The fragment pipeline is controlled by various registers, sporting a variety of interesting hardware features. See Copetti's 3DS Article and the WIP Citro3D Docs for more information.

The GPU also holds 6MB of dedicated video memory (10MB on New 3DS, though support seems broken in libctru), which is enough to hold full-size double-buffered display buffers. Textures can also be stored here, but support in Citro3D seems broken at the moment.

The GPU is a beefy boi and will almost never be a bottleneck in emulation, even when running in 800x480 mode. You should use VRAM display buffers for slightly improved performance, though these are incompatible with the print console; when using a console, linear memory must be used.

## Linear Memory

Linear Memory is a region of the system's main memory that is visible to various hardware devices, namely the DSP and the GPU. Generally, it should be reserved for communication with those devices.

## Picasso

Picasso is a tool provided by DevkitPro that handles 3DS vertex and geometry shader compilation. Shader source files are provided to the tool, resulting in a DVLB output that should be included via a tool such as bin2s. The DVLB is a "Shader Binary," which includes several DVLEs, or "Entrypoints." Generally, you should aim to put all of your entrypoints into one DVLB if possible, as switching DVLEs is cheap while switching DVLBs is expensive, since the entire DVLB must be uploaded to the GPU. DVLB and DVLE swaps are treated identically from an API perspective.

Shaders have inputs, outputs, uniforms, and constants.
- Inputs are data provided by Attribute Loaders, which tell the GPU how to arrange data from the prior stage.
- Outputs are data written by the shader. All declared outputs should be written.
- Uniforms are data that can be modified at-will by the CPU. They hold the same value for all concurrent invocations of the shader program.
- Constants are actually just special uniforms handled by Citro3D. Unfortunately, they are also slow, as they are re-sent when switching DVLEs within a single DVLB. This may be refined in the future, but for now, you should just stick to using uniforms for a slight performance improvement and GPU command reduction.
  - Due to a bug in Citro3D or libctru, one float constant is required per-uniform.
  - There is another reason to use uniforms over constants: constants are not shared. This means that constants are NEVER valid to use inside of shader source files without DVLEs, since they will never be allocated registers in the shared uniform space. Really, stick to uniforms.
  
Most uniforms will be 24-bit floating-point uniforms. Other types exist, but their usage is very limited. See Picasso's documentation and the 3DBrew Wiki's page on the PICA200's shader instruction set.

Inputs can be loaded from non-float formats, but they will be converted to floats by the GPU.

## The Displays

The 3DS features an 800x240 top display and a 320x240 bottom display. Official software always rendered 400x240 (and maybe 400x480 downscaled for antialiasing?) to the top display, but homebrew can utilize the full width of the display to provide an incredibly sharp 800x240 image. An internal rendering resolution of 800x480 can also be used, providing an absurdly clean anti-aliased 800x240 output.

Stereoscopic 3D rendering is accomplished by rendering the scene twice, with slightly different camera locations and tilts for each eye. This is very expensive and great care needs to be taken to avoid a skyrocketing GPU command count and bad slowdown.

## General Information

Here is some general info that will help when programming for the 3DS, in no particular order.

Random memory accesses are quite fast on 3DS. Data locality is always helpful, but it may be difficult to notice in benchmarks. Code locality is still quite beneficial, however, so care should be taken in regards to code layout.

Benchmarking is difficult for a number of reasons, as numbers have an abnormally high amount of variance, at least in my experience. I recommend dumping raw, non-averaged profiling data via GDB print statements and evaluating it in custom PC software.

Ensure that your console has an up-to-date Luma3DS installation and that your DSP firmware has been dumped if you are not bundling a custom firmware. Never bundle the stock firmware.

Most system tasks are triggered synchronously and can be ignored or disabled, such as entering sleep mode and opening the home menu. You may need to reduce the AppCpuTimeLimit when these events take place to avoid lag in the home menu. The console can also hang in strange ways that not even I can explain.

## Links

- [DevkitPro Getting Started](https://devkitpro.org/wiki/Getting_Started): This details how to install DevkitPro for your platform of choice.
- [DevkitPro 3DS Dev Forum](https://devkitpro.org/viewforum.php?f=39): This is a decent beginner's resource, but I created a post nine months ago that was left in limbo. Your mileage may vary.
- [DevkitPro 3ds-examples Repository](https://github.com/devkitPro/3ds-examples): This repository features various "getting-started" software examples.
- [WIP Citro3D Documentation](https://oreo639.github.io/citro3d/index.html): This is documentation for Citro3D, but it's unfinished. There's still some good stuff.
- [libctru Documentation](https://libctru.devkitpro.org/index.html): LibCTRU's documentation is somewhat barebones, but it's a decent codex of terms and types.
- [Copetti's 3DS Article](https://www.copetti.org/): This is a masterful resource for understanding the underlying architecture. It is especially useful for understanding the GPU's fragment pipeline.
- [BMaupin's 3DS Wiki](https://bmaupin.github.io/wiki/other/3ds/): This wiki provides various "getting-started" resources related to tooling.
- [Official ARM Documentation](https://developer.arm.com/): The 3DS's main CPU uses a very open platform, and thus, official documentation is available. However, its layout is mind-bending and very fragmented.
- [The 3DBrew Wiki](https://www.3dbrew.org/wiki/Main_Page): This wiki has lots of low-level hardware information.
- [Picasso's manual](https://github.com/devkitPro/picasso/blob/master/Manual.md): This manual describes how to use Picasso, which is very hard to wrap your head around.
- [3DS Development Resources](https://github.com/Wyatt-James/3ds-resources): The home of this very document. Extra resources and up-to-date versions can be found here.

## Special Thanks
- Thank you to the DevkitPro team.
- Thank you to all who have contributed to the various 3DS development resources.
- Thank you to The Big N for designing and manufacturing these excellent little rectangles.
- Thank you for reading and good luck programming!
