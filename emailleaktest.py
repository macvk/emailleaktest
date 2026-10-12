#!/usr/bin/env python3

# Email IP leak test client for bash.ws.
# Project: https://github.com/macvk/emailleaktest
# SPDX-License-Identifier: MIT

import getpass
import json
import re
import shutil
import smtplib
import ssl
import subprocess
import sys
import time
from email.message import EmailMessage
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


VERSION = '1.0.0'
API_DOMAIN = 'bash.ws'
API_BASE = 'https://' + API_DOMAIN
POLL_INTERVAL = 1
REQUEST_TIMEOUT = 30


class APIError(Exception):
    pass


def request(path):
    headers = {'User-Agent': 'bash.ws emailleaktest-python/' + VERSION}

    try:
        with urlopen(Request(API_BASE + path, headers=headers), timeout=REQUEST_TIMEOUT) as response:
            return response.read().decode('utf-8').strip()
    except HTTPError as error:
        raise APIError('{} returned HTTP {}'.format(path, error.code)) from error
    except URLError as error:
        raise APIError(str(error.reason)) from error


def request_test_id():
    test_id = request('/id').lower()

    if not re.fullmatch(r'[a-z0-9]{16}', test_id):
        raise APIError('invalid test ID returned by /id')

    return test_id


def decode_records(data):
    try:
        response = json.loads(data)
    except (TypeError, ValueError) as error:
        raise APIError('invalid response from the email leak test') from error

    if isinstance(response, dict) and isinstance(response.get('error'), str):
        raise APIError(response['error'])

    if not isinstance(response, list) or not all(isinstance(record, dict) for record in response):
        raise APIError('invalid response from the email leak test')

    return response


def request_result(test_id):
    return decode_records(request('/email-leak-test/test/{}?json'.format(test_id)))


def prompt(label, default=''):
    suffix = ' [{}]'.format(default) if default else ''

    try:
        value = input('{}{}: '.format(label, suffix)).strip()
    except EOFError as error:
        raise APIError('unable to read SMTP settings') from error

    return value or default


def send_with_mail(mail, recipient):
    try:
        subprocess.run(
            [mail, '-s', 'Test', recipient],
            input='',
            text=True,
            stdout=subprocess.DEVNULL,
            check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        raise APIError('email was not sent') from error


def send_with_smtp(recipient):
    sender = prompt('Sender email')

    if not re.fullmatch(r'[^@\s]+@[^@\s]+', sender):
        raise APIError('invalid sender email')

    server = prompt('SMTP server', 'smtp.' + sender.rsplit('@', 1)[1])
    port_value = prompt('SMTP port', '587')
    username = prompt('SMTP username', sender)

    try:
        port = int(port_value)
    except ValueError as error:
        raise APIError('invalid SMTP port') from error

    if port < 1 or port > 65535:
        raise APIError('invalid SMTP port')

    try:
        password = getpass.getpass('SMTP password: ')
    except (EOFError, KeyboardInterrupt) as error:
        raise APIError('unable to read SMTP password') from error

    message = EmailMessage()
    message['From'] = sender
    message['To'] = recipient
    message['Subject'] = 'Test'
    message.set_content('')

    try:
        context = ssl.create_default_context()

        with smtplib.SMTP(server, port, timeout=REQUEST_TIMEOUT) as client:
            client.ehlo()

            if not client.has_extn('starttls'):
                raise APIError('SMTP server does not support STARTTLS')

            client.starttls(context=context)
            client.ehlo()
            client.login(username, password)
            client.send_message(message)
    except (OSError, smtplib.SMTPException) as error:
        raise APIError('email was not sent: {}'.format(error)) from error


def send_email(test_id):
    recipient = '{}@{}'.format(test_id, API_DOMAIN)
    mail = shutil.which('mail')

    if mail is not None:
        send_with_mail(mail, recipient)
        return

    send_with_smtp(recipient)


def text(record, field):
    value = record.get(field)
    return value if isinstance(value, str) else ''


def records_of_type(records, record_type):
    return [record for record in records if record.get('type') == record_type and text(record, 'ip')]


def test_complete(records):
    return any(record.get('type') == 'done' and text(record, 'done') == '1' for record in records)


def format_address(record):
    address = text(record, 'ip')
    country = text(record, 'country_name')
    asn = text(record, 'asn')

    if not country:
        return address

    if not asn:
        return '{} [{}]'.format(address, country)

    return '{} [{}, {}]'.format(address, country, asn)


def print_result(records):
    addresses = records_of_type(records, 'ip')
    mail_addresses = records_of_type(records, 'mail')
    conclusions = records_of_type(records, 'conclusion')

    print('Your IP:')

    for record in addresses:
        print(format_address(record))

    print()

    if not mail_addresses:
        print('No IPs found in mail header')
    elif len(mail_addresses) == 1:
        print('Mail header has got 1 IP:')
    else:
        print('Mail header has got {} IPs:'.format(len(mail_addresses)))

    for record in mail_addresses:
        print(format_address(record))

    if not conclusions:
        raise APIError('conclusion missing from the email leak test result')

    print()
    print('Conclusion:')

    for record in conclusions:
        print(text(record, 'ip'))


def run():
    test_id = request_test_id()
    request_result(test_id)
    send_email(test_id)

    while True:
        time.sleep(POLL_INTERVAL)
        records = request_result(test_id)

        if test_complete(records):
            print()
            print_result(records)
            return


def main():
    try:
        run()
    except APIError as error:
        print('Email leak test failed: {}'.format(error), file=sys.stderr)
        return 1

    return 0


if __name__ == '__main__':
    sys.exit(main())
