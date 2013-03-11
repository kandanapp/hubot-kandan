# Hubot Adapter for Kandan

## Description 
A Hubot adapter for [Kandan](http://kandanapp.com)

## WARNING
Currently the Hubot Adapter for Kandan only will work with the code in the Kandan __MASTER__ branch and not in any
of tagged/released branches.

## Installation & Usage

* Install Kandan --> [Installation Instructions](https://github.com/kandanapp/kandan/blob/master/DEPLOY.md)
* Once you've installed Kandan but before you start the server run these commands:

```
rake kandan:boot_hubot
rake kandan:hubot_access_key
```
* Take note of the output of the command `rake kandan:hubot_access_key` as you will need it later
* Download [Hubot from GitHub](https://github.com/github/hubot/archive/v2.4.7.zip)
* Unzip hubot-2.4.7

```
cd hubot-2.4.7
npm install
make package
cd hubot
git clone git@github.com:kandanapp/hubot-kandan.git node_modules/hubot-kandan
npm install faye
```	

* Add `"hubot-kandan": "1.0"` as a dependency in your hubots `package.json`
* Remove `"redis-brain.coffee",` from hubot-scripts.json 

You will need to set a few environment variables in order for it to work properly

`export HUBOT_KANDAN_HOST="hostname.com" HUBOT_KANDAN_PORT="port-if-not-80" HUBOT_KANDAN_TOKEN="hubot_access_key"`

Now just fire up hubot using: `./bin/hubot -a kandan`

## Contributing
Contributions are welcome. To get your work considered please do the following:

1. Fork this project
2. Create a feature/bug fix branch
3. Hack away, committing often and frequently
4. Push your branch up to your fork
5. Submit a pull request

## License
Copyright (c) 2012 Bushido Inc.

Copyright (c) 2012-2013 KandanApp

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
