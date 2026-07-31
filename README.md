# Security Monitoring Ansible V8

Automatyczne wdrożenie na Ubuntu 24.04+ lub Debianie 13+: Wazuh 4.14.6, reguły SOCFortress, Zabbix 7.0 LTS, Zabbix Agent 2 na hoście, Nginx Proxy Manager oraz wspólna MariaDB.

## Najważniejsze zmiany V8

- `run.sh` przyjmuje prosty parametr katalogu danych,
- `run.sh` może wyłączyć zarządzany certyfikat self-signed,
- opcje są zapisywane w `group_vars/all.yml`, więc kolejne uruchomienia je pamiętają,
- usunięto obowiązek używania `security_monitoring_required_mountpoint`,
- wyłączenie self-signed bezpiecznie usuwa zarządzany domyślny vhost HTTPS,
- provisioner NPM nadal działa przy każdym wdrożeniu i jest idempotentny.

## Najprostsze uruchomienie

Domyślne ustawienia z `group_vars/all.yml`:

```bash
./run.sh
```

Dane na osobnym dysku:

```bash
./run.sh -d /data/security-monitoring
```

Dane na osobnym dysku, bez certyfikatu self-signed:

```bash
./run.sh -d /data/security-monitoring -n
```

Ponowne włączenie self-signed:

```bash
./run.sh --https
```

Pomoc:

```bash
./run.sh --help
```

## Opcje run.sh

```text
-d, --data-root ŚCIEŻKA  główny katalog wdrożenia i trwałych danych
-n, --no-https           nie generuje i nie podpina certyfikatu self-signed
    --no-self-signed     alias opcji --no-https
    --https              ponownie włącza zarządzany self-signed
-h, --help               pomoc
```

Opcja `--data-root` zapisuje w `group_vars/all.yml` także wszystkie katalogi składowe. Dzięki temu działa również wtedy, gdy plik pochodzi ze starszej wersji i zawiera jawne ścieżki `/opt/...`.

Przykładowy układ dla `-d /data/security-monitoring`:

```text
/data/security-monitoring/shared-database
/data/security-monitoring/nginx-proxy-manager
/data/security-monitoring/wazuh
/data/security-monitoring/wazuh-persistent
/data/security-monitoring/wazuh-socfortress
/data/security-monitoring/zabbix
```

Skrypt nie wymaga, aby wskazana ścieżka była osobnym punktem montowania. Przy użyciu dodatkowego dysku przed wdrożeniem warto sprawdzić:

```bash
findmnt /data
df -h /data
```

Nie zmieniaj ścieżki działającej instalacji bez migracji istniejących danych.

## Pierwsze przygotowanie

```bash
cp group_vars/all.yml.example group_vars/all.yml
chmod 600 group_vars/all.yml
nano group_vars/all.yml
./run.sh -d /data/security-monitoring
```

## Adresy

Przy włączonym self-signed:

```text
http://IP/zabbix/
http://IP/wazuh/
https://IP/zabbix/
https://IP/wazuh/
http://IP:81/
```

Przy `--no-https` projekt nie generuje ani nie podpina własnego certyfikatu self-signed. Routing HTTP pozostaje aktywny. Port 443 Nginx Proxy Manager pozostaje standardowo dostępny, aby można było później podpiąć własny certyfikat.

## NPM i routing

Provisioner przy każdym uruchomieniu:

- tworzy brakujący Proxy Host dla IP,
- aktualizuje zarządzane ścieżki `/zabbix/` i `/wazuh/`,
- zachowuje dodatkowe domeny i Custom Locations,
- zachowuje certyfikat dodany ręcznie,
- po wyłączeniu self-signed odłącza tylko certyfikat utworzony przez projekt,
- nie wykonuje zapisu, gdy konfiguracja jest już zgodna.

Po ręcznej zmianie hasła administratora NPM zaktualizuj również `npm_admin_password` w `group_vars/all.yml`.

## Zabbix Agent 2

W Zabbix Web sprawdź:

```text
Data collection -> Hosts -> Zabbix server -> Interfaces
```

Ustaw adres IP VM i port `10050`. `127.0.0.1` z perspektywy kontenera Zabbix Server wskazuje sam kontener.

## Czyszczenie środowiska testowego

```bash
sudo ./cleanup_fresh.sh
```

Ponieważ `run.sh -d` zapisuje ścieżkę w `group_vars/all.yml`, skrypt czyszczący odczyta właściwy katalog.
