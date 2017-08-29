#!/usr/bin/env python

import logging
import os
import ast
import six
import subprocess
import sys

def run_subproc(fn, **kwargs):
    env = os.environ.copy()
    for k, v in kwargs.items():
        env[six.text_type(k)] = v
    try:
        subproc = subprocess.Popen(fn, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE,
                                   env=env)
        stdout, stderr = subproc.communicate()
    except OSError as exc:
        ret = -1
        stderr = six.text_type(exc)
        stdout = ""
    else:
        ret = subproc.returncode
    if not ret:
        ret = 0
    return ret, stdout, stderr


def main(argv=sys.argv):
    log = logging.getLogger('vzip-install')
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(
        logging.Formatter(
            '[%(asctime)s] (%(name)s) [%(levelname)s] %(message)s'))
    log.addHandler(handler)
    log.setLevel('DEBUG')

    env = os.environ.copy()

    ma = env['master_ip_address'].replace('u','')
    mh = env['master_host'].replace('u','')
    a = env['ip_addresses'].replace('u','')
    h = env['host_names'].replace('u','')

    ma = ast.literal_eval(ma)
    mh = ast.literal_eval(mh)
    a = ast.literal_eval(a)
    h = ast.literal_eval(h)

    ip_addresses = ma.values() + a.values()
    host_names = mh.values() + h.values()
    hosts = zip(ip_addresses, host_names)

    # construct correct hosts file containing all cluster hosts
    for host in hosts:
        with open('/etc/hosts', 'a') as f:
            f.write(' '.join(host) + '\n')

    # add all ip addresses to known-hosts and
    # copy constructed /etc/hosts to all hosts in cluster
    for host in host_names:

        cmd = ['ssh-keyscan', host]
        ret, out, err = run_subproc(cmd)
        log.debug("ssh-keyscan output: %s", out)
        if err:
            log.error("ssh-keyscan return code %s:\n%s", ret, err)
            exit(ret)

        with open('/root/.ssh/known_hosts', 'a') as f:
            f.write(out + '\n')

        cmd = ['scp', '/etc/hosts', host + ':/etc/' ]
        ret, out, err = run_subproc(cmd)
        log.debug("scp output: %s", out)
        if err:
            log.error("scp return code %s:\n%s", ret, err)
            exit(ret)

    out_path = env['heat_outputs_path']

    with open(out_path + ".master_host", 'w') as f:
        f.write(mh.values()[0])

    with open(out_path + ".host_names", 'w') as f:
        f.write(' '.join(host_names))

if __name__ == '__main__':
    sys.exit(main(sys.argv))

