#!/usr/bin/env bash

# Initial installs and updates (git, rbenv, ruby-build)
sudo -s -- <<'EOF'
  apt-get -q update; apt-get -y upgrade
  apt-get -y install git-core libssl-dev libreadline-dev zlib1g-dev ruby-dev

  # Install and configure rbenv
  pushd /usr/local
    git clone git://github.com/rbenv/rbenv.git
    ln -s /usr/local/rbenv/bin/rbenv /usr/local/bin/

    # Add RBENV_ROOT to global environment
    echo 'RBENV_ROOT=/usr/local/rbenv' >> /etc/environment

    pushd rbenv
      ./src/configure && make -C src
    popd

    # chown to vagrant so gem/bundler doesn't complain about permissions
    chown -R vagrant:vagrant rbenv
  popd

  # Install ruby-build for 'rbenv install ...'
  pushd /tmp
    git clone git://github.com/rbenv/ruby-build.git
    cd ./ruby-build && ./install.sh
  popd
EOF

# Reload /etc/environment to pick up rbenv changes
while read -r line; do eval "export ${line}"; done < /etc/environment

# Install ruby version needed for blog.symons.io
eval "$(rbenv init -)"

rbenv install 2.3.0
rbenv rehash

# Make sure site folder exists and is a directory
SITE_FOLDER=/vagrant/site

if [[ -e "${SITE_FOLDER}" && ! -d "${SITE_FOLDER}" ]]; then
  rm -xf "${SITE_FOLDER}"
fi
if [[ ! -e "${SITE_FOLDER}" ]]; then
  mkdir "${SITE_FOLDER}"
fi

# Clean site folder
find "${SITE_FOLDER}" -mindepth 1 -delete

# Clone and set up site repositories
pushd /vagrant/site
  # blog.symons.io
  git clone https://github.com/Multimac/blog.git
  pushd blog
    gem install bundler && bundle install
  popd
popd

# Copy upstart configs
sudo -s -- <<'EOF'
  # nullglob so '*/upstart.conf' isn't used in for loop
  shopt -s nullglob

  pushd /vagrant/site
    mkdir /etc/init/site
    for UPSTART_CONF in */upstart.conf; do
      FOLDER_NAME=$(dirname ${UPSTART_CONF})

      cp ${UPSTART_CONF} /etc/init/site/${FOLDER_NAME}.conf
      start site/${FOLDER_NAME}
    done
  popd
EOF
