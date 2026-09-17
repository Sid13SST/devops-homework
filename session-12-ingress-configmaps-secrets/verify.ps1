<#
  Session 12 verification runner.
  Usage:  .\verify.ps1 03      (03 | 04 | 09 | 13 | 13b | 14)

  Echoes each command, then actually runs it, so a screenshot of this script's
  output shows the real command next to its real output. Nothing is simulated.
#>
param([Parameter(Mandatory=$true)][string]$Task)

$bash    = "C:\Program Files\Git\bin\bash.exe"
$openssl = "C:\Program Files\Git\usr\bin\openssl.exe"

function Run {
    param([string]$Label, [scriptblock]$Block)
    Write-Host ""
    Write-Host "PS> $Label" -ForegroundColor Cyan
    & $Block
}

switch ($Task) {

  '03' {
    Run 'kubectl apply -f 02-secret/db-secret.yaml' { kubectl apply -f 02-secret/db-secret.yaml }
    Run 'kubectl get secret yatri-db-secret'        { kubectl get secret yatri-db-secret }
    Run 'kubectl describe secret yatri-db-secret'   { kubectl describe secret yatri-db-secret }
    # PowerShell equivalent of:  ... | base64 --decode
    # (piping into base64 from PowerShell appends a newline, so decode natively)
    Run 'kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_PASSWORD}"  ->  base64 decoded' {
        $v = kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_PASSWORD}"
        Write-Host ("  encoded : " + $v)
        Write-Host ("  decoded : " + [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($v)))
    }
    Run 'kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_USER}"  ->  base64 decoded' {
        $v = kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_USER}"
        Write-Host ("  encoded : " + $v)
        Write-Host ("  decoded : " + [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($v)))
    }
  }

  '04' {
    Run 'echo "secretpassword" | xxd      # BROKEN: trailing 0a' { & $bash -c 'echo "secretpassword" | xxd' }
    Run 'echo "secretpassword" | base64'                          { & $bash -c 'echo "secretpassword" | base64' }
    Run 'echo -n "secretpassword" | xxd   # CORRECT: no newline'  { & $bash -c 'echo -n "secretpassword" | xxd' }
    Run 'echo -n "secretpassword" | base64'                       { & $bash -c 'echo -n "secretpassword" | base64' }
    Write-Host ""
    Write-Host "Wrong (with newline): $(& $bash -c 'echo "secretpassword" | base64')"
    Write-Host "Right (no newline):   $(& $bash -c 'echo -n "secretpassword" | base64')"
  }

  '09' {
    Run 'minikube ip' { minikube ip }
    Run 'grep -E "yatri|campus" /etc/hosts   (on the node)' { minikube ssh -- 'grep -E "yatri|campus" /etc/hosts' }
    Run 'curl -s http://yatri.local/ | grep -i title        (resolved BY NAME)' {
        minikube ssh -- 'curl -s http://yatri.local/ | grep -i title'
    }
    Run 'curl -s http://yatri.local/api/ | head -3          (resolved BY NAME)' {
        minikube ssh -- 'curl -s http://yatri.local/api/ | head -3'
    }
  }

  '13cert' {
    Run 'kubectl get secret campus-tls-cert' { kubectl get secret campus-tls-cert }
    Run 'openssl x509 -in 03-ingress/tls.crt -noout -subject -dates -ext subjectAltName' {
        & $openssl x509 -in 03-ingress/tls.crt -noout -subject -dates -ext subjectAltName
    }
  }

  '13' {
    Run 'kubectl get secret campus-tls-cert' { kubectl get secret campus-tls-cert }
    Run 'openssl x509 -in 03-ingress/tls.crt -noout -subject -dates' {
        & $openssl x509 -in 03-ingress/tls.crt -noout -subject -dates
    }
    Run 'curl -k -o /dev/null -w "HTTP %{http_code}" https://portal.campus.local/   (port 443)' {
        minikube ssh -- 'curl -k -s -o /dev/null -w "HTTP %{http_code}\n" --resolve portal.campus.local:443:127.0.0.1 https://portal.campus.local/'
    }
  }

  '13b' {
    Run 'curl -k -v https://portal.campus.local/  | grep subject/issuer/SSL/HTTP' {
        minikube ssh -- 'curl -k -sv --resolve portal.campus.local:443:127.0.0.1 https://portal.campus.local/ 2>&1 | grep -E "subject:|issuer:|SSL connection using|HTTP/1"'
    }
  }

  '14' {
    Run 'kubectl get configmap,secret,ingress,deploy,svc,pods -l app=yatri-app' {
        kubectl get configmap,secret,ingress,deploy,svc,pods -l app=yatri-app
    }
  }

  default { Write-Host "Unknown task '$Task'. Use 03 | 04 | 09 | 13 | 13b | 14" -ForegroundColor Red }
}
Write-Host ""
