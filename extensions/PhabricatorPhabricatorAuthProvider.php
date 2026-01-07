<?php

/*
Based on https://github.com/zhegao9/phabricator-keycloak-extension
Apache License,  Version 2.0
                          
*/

final class PhabricatorAuthentikAuthProvider extends PhabricatorOAuth2AuthProvider {

  const PROPERTY_AUTHENTIK_APPLICATION = 'oauth2:authentik:application';
  const PROPERTY_AUTHENTIK_URI = 'oauth2:authentik:uri';

  public function getProviderName() {
    return pht('authentik');
  }

  protected function newOAuthAdapter() {
    $config = $this->getProviderConfig();
    return id(new PhutilAuthentikAuthAdapter())
      ->setAuthentikURI($config->getProperty(self::PROPERTY_AUTHENTIK_URI))
      ->setAuthentikApplication($config->getProperty(self::PROPERTY_AUTHENTIK_APPLICATION));
  }

  protected function getProviderConfigurationHelp() {
    $login_uri = PhabricatorEnv::getURI($this->getLoginURI());

    return pht(
      "To configure Authentik OAuth, create a new OpenID typed client." .
      "\n\n" .
      "When creating your OpenID typed client, use these settings:" .
      "\n\n" .
      "  - **Redirect URI:** Set this to: `%s`" .
      "\n\n" .
      "After completing configuration, copy the **Client ID** and " .
      "**Client Secret** to the fields above.",
      $login_uri);
  }

  private function isCreate() {
    return !$this->getProviderConfig()->getID();
  }

  public function readFormValuesFromProvider() {
    $config = $this->getProviderConfig();
    $uri = $config->getProperty(self::PROPERTY_AUTHENTIK_URI);
    $application = $config->getProperty(self::PROPERTY_AUTHENTIK_APPLICATION);

    return parent::readFormValuesFromProvider() + array(
      self::PROPERTY_AUTHENTIK_APPLICATION => $application,
      self::PROPERTY_AUTHENTIK_URI => $uri,
    );
  }

  public function readFormValuesFromRequest(AphrontRequest $request) {

    return parent::readFormValuesFromRequest($request) + array(
      self::PROPERTY_AUTHENTIK_APPLICATION => $request->getStr(self::PROPERTY_AUTHENTIK_APPLICATION),
      self::PROPERTY_AUTHENTIK_URI =>
        $request->getStr(self::PROPERTY_AUTHENTIK_URI),
    );
  }

  public function processEditForm(
    AphrontRequest $request,
    array $values) {

    $is_setup = $this->isCreate();

    if (!$is_setup) {
      list($errors, $issues, $values) =
        parent::processEditForm($request, $values);
    } else {
      $errors = array();
      $issues = array();
    }

    $key_application = self::PROPERTY_AUTHENTIK_APPLICATION;
    $key_uri = self::PROPERTY_AUTHENTIK_URI;

    if (!strlen($values[$key_application])) {
      $errors[] = pht('Application name is required.');
      $issues[$key_application] = pht('Required');
    }

    if (!strlen($values[$key_uri])) {
      $errors[] = pht('Base URI is required.');
      $issues[$key_uri] = pht('Required');
    } else {
      $uri = new PhutilURI($values[$key_uri]);
      if (!$uri->getProtocol()) {
        $errors[] = pht(
          'Base URI should include protocol (like "%s").',
          'https://');
        $issues[$key_uri] = pht('Invalid');
      }
    }

    return array($errors, $issues, $values);
  }

  public function extendEditForm(
    AphrontRequest $request,
    AphrontFormView $form,
    array $values,
    array $issues) {

    $is_setup = $this->isCreate();

    $e_required = $request->isFormPost() ? null : true;

    $v_application = $values[self::PROPERTY_AUTHENTIK_APPLICATION];
    $e_application = idx($issues, self::PROPERTY_AUTHENTIK_APPLICATION, $e_required);

    $v_uri = $values[self::PROPERTY_AUTHENTIK_URI];
    $e_uri = idx($issues, self::PROPERTY_AUTHENTIK_URI, $e_required);

    $form
      ->appendChild(
        id(new AphrontFormTextControl())
          ->setLabel(pht('Base URI'))
          ->setValue($v_uri)
          ->setName(self::PROPERTY_AUTHENTIK_URI)
          ->setError($e_uri))
      ->appendChild(
        id(new AphrontFormTextControl())
          ->setLabel(pht('Application Name'))
          ->setValue($v_application)
          ->setName(self::PROPERTY_AUTHENTIK_APPLICATION)
          ->setError($e_application));

    if (!$is_setup) {
      parent::extendEditForm($request, $form, $values, $issues);
    }
  }

  public function hasSetupStep() {
    return true;
  }
}
