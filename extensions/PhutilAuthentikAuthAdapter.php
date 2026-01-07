<?php

/*
Based on https://github.com/zhegao9/phabricator-keycloak-extension
Apache License,  Version 2.0
                          
*/

final class PhutilAuthentikAuthAdapter extends PhutilOAuthAuthAdapter {

    private $wellKnownConfiguration;
    public $authentikURI;
    public $authentikApplication;

    public function getAdapterType() {
        return 'Authentik';
    }

    public function getAuthentikApplication() {
        return $this->authentikApplication;
    }

    public function setAuthentikApplication($application) {
        $this->authentikApplication = $application;
        return $this;
    }

    public function getAuthentikURI() {
        return new PhutilURI($this->authentikURI);
    }
    public function setAuthentikURI($uri) {
        $this->authentikURI = $uri;
        return $this;
    }

    public function getAdapterDomain() {
        return $this->getAuthentikURI()->getDomain();
    }

    public function getAccountID() {
        return $this->getOAuthAccountData('sub');
    }

    public function getAccountEmail() {
        return $this->getOAuthAccountData('email');
    }

    public function getAccountName() {
        return $this->getOAuthAccountData('preferred_username');
    }

    public function getAccountRealName() {
        return $this->getOAuthAccountData('name');
    }

    public function getAccountImageURI() {
        return null;
    }

    public function getAccountURI() {
        return null;
    }

    protected function getAuthenticateBaseURI() {
        return $this->getWellKnownConfiguration('authorization_endpoint');
    }

    protected function getTokenBaseURI() {
        return $this->getWellKnownConfiguration('token_endpoint');
    }

    public function getScope() {
        return 'openid profile email';
    }

    public function getExtraAuthenticateParameters() {
        return array(
            'response_type' => 'code',
        );
    }

    public function getExtraTokenParameters() {
        return array(
            'grant_type' => 'authorization_code',
        );
    }

    public function getAccessToken() {
        return $this->getAccessTokenData('access_token');
    }

    protected function loadOAuthAccountData() {
        $uri = $this->getWellKnownConfiguration('userinfo_endpoint');

        $future = new HTTPSFuture($uri);

        $token = $this->getAccessToken();
        $future->addHeader('Authorization', "Bearer {$token}");

        list($body) = $future->resolvex();

        try {
            $result = phutil_json_decode($body);
            return $result;
        } catch (PhutilJSONParserException $ex) {
            throw new PhutilProxyException(
                pht('Expected valid JSON response from OIDC account data request.'),
                $ex);
        }
    }

    private function getWellKnownConfiguration($key) {
        if ($this->wellKnownConfiguration === null) {
            $uri = $this->getAuthentikURI();

            $path = $uri->getPath();
            $path = rtrim($path, '/') . '/application/o/' . $this->authentikApplication . '/.well-known/openid-configuration';

            $uri->setPath($path);

            $uri = phutil_string_cast($uri);

            $future = new HTTPSFuture($uri);
            list($body) = $future->resolvex();

            $data = phutil_json_decode($body);

            $this->wellKnownConfiguration = $data;
        }

        if (!isset($this->wellKnownConfiguration[$key])) {
            throw new Exception(
                pht(
                    'Expected key "%s" in well-known configuration!',
                    $key));
        }

        return $this->wellKnownConfiguration[$key];
    }
}
