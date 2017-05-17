# upcloud_api

- [Homepage](https://github.com/Smarre/upcloud_api)
- [Documentation](http://www.rubydoc.info/gems/upcloud_api)

## Description

Ruby implementation of [Upcloud API](https://www.upcloud.com/documentation/api/),
meant for programmable maintenance of virtual private servers in Upcloud’s system.

## Features

* Implements Upcloud API version 1.2.3.

### Known problems

* Load/eject CDROM not done.
* [timezones API method](https://www.upcloud.com/api/1.2.3/6-timezones/) is not implemented.

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

Contributions are accepted :)

## Testing

There is bunch of unit tests implemented with rspec, you can run the suite with:

    rspec --format documentation

WARNING: RUNNING TESTS CONSUMES YOUR CREDITS

## License

(The MIT License)

Copyright (c) 2016 Qentinel Group
Copyright (c) 2016 Samu Voutilainen

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
