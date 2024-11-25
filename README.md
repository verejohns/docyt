[![CircleCI](https://circleci.com/bb/kmnss/auth_service.svg?style=svg&circle-token=b0ac193e0a3038a24720d0123399c1e9107e9b05)](https://circleci.com/bb/kmnss/auth_service)

reports_service is a micro service which is responsible for managing the reports of Docyt businesses. Technical design:

https://docytinc.atlassian.net/wiki/spaces/DOC/pages/1653014529/Reporting+Service+2.0+Technical+design

## Ruby version

We are using Ruby 2.6.3 (see .ruby-version file)

## System dependencies

Please have the following software installed in your system:

* PostgtreSQL

On Mac you can run:

    brew install postgresql

## Run Rails server

    bin/server.sh

It will listen on port 3000 (SSL only). You can open up the following URL in browser to access the server:

    https://auth.localhost.docyt.com:3000/

If browser complains about the SSL error, it is safe to ignore it and proceed. You can also install Docyt's CA file by following [this instruction](https://docytinc.atlassian.net/wiki/spaces/DOC/pages/774733847/Add+Docyt+CA+file+to+the+list+of+trusted+certificates)
