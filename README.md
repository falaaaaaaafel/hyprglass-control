# # Hyprglass Control Center

\> \*\*⚠️ Disclaimer\*\*  

\> This application is currently in active development (work in progress) and may contain bugs or incomplete features. I am \*\*falaaaaaaafel\*\*, and I am not a programmer—I built this project with the help of AI. Please use it at your own discretion, and feedback or contributions are always welcome!

A Quickshell control center for the \[Hyprglass\](https://github.com/) plugin on Hyprland.  

Adjust blur, refraction, opacity, chromatic aberration, Fresnel highlights and more, with optional Caelestia Shell integration.

\## Requirements

\- Hyprland with the Hyprglass plugin loaded

\- Quickshell

\- Python 3

\## Install

\`\`\`bash

git clone https://github.com/falaaaaaaafel/hyprglass-control
cd hyprglass-control

./install.sh

\`\`\`

Then run:

\`\`\`bash

quickshell -c hyprglass-control

\`\`\`

or search for \*\*"Hyprglass"\*\* in your application menu.

\## Uninstall

\`\`\`bash

rm -r \~/.config/quickshell/hyprglass-control

rm \~/.local/share/applications/hyprglass-control.desktop

\`\`\`

Your saved settings live in \`\~/.config/hyprglass-control/\` and are not removed.
