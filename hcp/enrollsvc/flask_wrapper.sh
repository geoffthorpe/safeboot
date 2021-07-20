#!/bin/bash

cd /hcp

. common.sh

expect_flask_user

FLASK_APP=rest_api flask run --host=0.0.0.0
