# upcloud_api

[Homepage](https://github.com/Smarre/upcloud_api)
[Documentation](http://www.rubydoc.info/gems/upcloud_api)

## Description

Ruby implementation of [Upcloud API](https://www.upcloud.com/documentation/api/),
meant for programmable maintenance of virtual private servers in Upcloud’s system.

## Features

* Basic server management calls done
* Implements API version 1.2.

### Known problems

* Some actions are still missing, most notably IP actions
* Most actions are mostly just wrappers over the API for convenience,
with no good documentation or integration.
* Load/eject CDROM not done.
* No methods for favorites

## Synopsis

    require "upcloud_api"
    api = UpcloudApi.new "usernya", "passwordnya"
    api.delete_server "b6ee337e-a7d8-4d27-8ed6-06e26c23265d"

## Requirements

* Ruby 2.1 or larger (may work with older releases, but no guarantee)
* Account to Upcloud service

## Install

    gem install upcloud_api

## Developers

I’ve only created actions I personally need, for my own project. In case you
need some other actions, please open a pull request and I’ll merge it,
or if you have greater plans for this project, I can make you co-author
or just transfer the project to you.

## API account credentials

Export your UpCloud API account username and password as environment variables:

     export UPCLOUD_USERNAME="XXX"
     export UPCLOUD_PASSWORD="YYY"

## Testing

There is bunch of unit tests implemented with rspec, you can run the suite with

    rspec --format documentation

RUNNING TESTS CONSUMES YOUR CREDITS

## License

(The MIT License)

Copyright (c) 2016 Qentinel Group

Copyright (c) 2015 Samu Voutilainen

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
