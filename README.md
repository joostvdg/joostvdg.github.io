# Flusso CI/CD Docs

## Tools used
* Python2 or Python3
* pip - a python install tool (optional)
* mkdocs
* mkdocs-bootswatch
* nginx (optional)
* Docker (optional)

## Get started
To get started, confirm you have:
* python2 or python3 installed
    * python -version
* Either
    * directly install **mkdocs** and **mdocs-bootswatch**
    * use the install.sh (requires pip)
* Write some docs in Markdown!

# Build
To build you can use *mkdocs build*.
It will generate the static site in the folder **site**

# Run
You can run it with a live reload, via *mkdocs serve*.

# Docker / Distribute
There is a Dockerfile for distribution.
Simply run **rerun.sh** to build the docs, create a docker image and then run said docker image.

Or you can type all the commands yourself. Your choice.

# Troubleshooting
If pip install runs correctly and your system still can't find **mkdocs** chances are that binary is installed in your ```~/.local/bin``` and that is not in your ```PATH```. You can add it by doing:
```export PATH=$PATH:~/.local/bin```
This problem occurs when you didn't **sudo** the install.

# Help!
