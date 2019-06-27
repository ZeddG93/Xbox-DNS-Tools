"Xbox国内下载测速Dnsmasq辅助工具"
"=================================="
"Written by hmqgg| Weibo@窓辺十子"
"Thanks to Curl & Original Version Author DeLaJSR"
"=================================="

$unicoms = ".\unicom.txt"
$telecoms = ".\telecom.txt"
$dnslist = ".\dnslist.txt"
$domains = ".\domains.txt"
# $dldomain = "download.xbox.com"
# $fileurl = "/content/415608c3/a106049a3ce17ed469574da1edef85f60f6df9a6.xcp"
$dldomain = "assets1.xboxlive.cn"
$resolvdomain = "2-01-364c-0028.cdx.cedexis.net"
# $fileurl = "/8/9ac8760e-353b-4ea4-9a1e-cbaa9d4c01e1/08db4573-f0db-4a1a-ae9e-dd56b0e52ac8/1.0.0.3.dcb6764f-530f-441e-8db6-f10f24b30c31/The-Witcher-3-GOTY-ENPL_1.0.0.3_x64__p6y4d66jq0r3e"
$fileurl = "/3/40cc5f3a-c253-444d-b2dc-e4fec2e94cd6/cb0f9467-ce8c-47db-83d8-6444be60ba71/1.0.18.0.60c577ef-ca49-46c4-89f6-4b6b91a43612/ParadoxInteractive.ImperatorRome-MicrosoftStoreEdi_1.0.18.0_x64__zfnrdv2de78ny.msixvc"
$report = ".\report.txt"

If ([System.IO.File]::Exists($report)) {
    $ans = Read-Host "是否清除测速结果历史记录(y/n)"
    while ("y", "n" -notcontains $ans) {
        $ans = Read-Host "是否清除测速结果历史记录(y/n)"
    }

    If ($ans -eq "y") {
        Clear-Content $report
    }
}

$answer = Read-Host "测速模式为电信(t)/联通(u)/扩展(e)/全部(a)"
while ("t", "u", "e", "a" -notcontains $answer) {
    $answer = Read-Host "测速模式为电信(t)/联通(u)/扩展(e)/全部(a)"
}

"-----------------------------------------------"

$ses = @()
$dms = [IO.File]::ReadAllLines($domains)

If ($answer -eq "t") {
    "使用预置电信CDN列表"
    $ses = [IO.File]::ReadAllLines($telecoms)
    "-----------------------------------------------"
}
Elseif ($answer -eq "u") {
    "使用预置联通CDN列表"
    $ses = [IO.File]::ReadAllLines($unicoms)
    "-----------------------------------------------"
}
Elseif ($answer -eq "e") {
    $dnss = [IO.File]::ReadAllLines($dnslist)
    "使用本机上游和下列DNS查询CDN："
    [System.String]::Join("|", $dnss)
    "-----------------------------------------------"

    $ses += ($((Resolve-Dnsname -Name $resolvdomain).IP4Address))

    ForEach ($dns in $dnss) {
        Foreach ($dm in $dms) {
            $ses += ($((Resolve-Dnsname -Server $dns -Name $dm).IP4Address))
        }
        # 额外添加一个PSN下载域名，国内XBOX、PS4共用CDN，DNS查询PS4CDN存在一定可能获得更优IP
        # $ses += ($((Resolve-Dnsname -Server $dns -Name "gs2.ww.prod.dl.playstation.net").IP4Address))
    }
}
Else {
    $dnss = [IO.File]::ReadAllLines($dnslist)
    "使用预置CDN列表及本机上游和下列DNS查询："
    [System.String]::Join("|", $dnss)
    "-----------------------------------------------"

    $ses += ($((Resolve-Dnsname -Name $resolvdomain).IP4Address))

    ForEach ($dns in $dnss) {
        Foreach ($dm in $dms) {
            $ses += ($((Resolve-Dnsname -Server $dns -Name $dm).IP4Address))
        }
        # $ses += ($((Resolve-Dnsname -Server $dns -Name "gs2.ww.prod.dl.playstation.net").IP4Address))
    }
    $ses += [IO.File]::ReadAllLines($telecoms)
    $ses += [IO.File]::ReadAllLines($unicoms)
}

$ses = $ses | Select-Object -Unique

$arg2 = "Host: $dldomain"
$arg3 = "%{speed_download}"

[System.Collections.Generic.SortedDictionary[string, double]]$resultdic = @{ }

$len = $ses.Length

For ($i = 0; $i -lt $len; $i++) {
    Write-Progress -Activity "测速中" -Status "进度->" -PercentComplete ($i / $len * 100)
    $ip = $ses[$i]
    $arg1 = "http://$ip$fileurl"
    $bytes = [double](& ".\curl.exe" -s -o nul -m 10 -Y 204800 -y 5 --url $arg1 -H $arg2 -w $arg3 2>&1)
    $mibps = $bytes / [double]1024.0 / [double]1024.0
    $speed = "{0:N2}" -f $mibps
    # "[$ip]: $speed MB/s"

    If ($speed -ge 0.2) {
        $resultdic.Add($ip, $speed)
    }
}

$result = $resultdic.GetEnumerator() | Sort-Object -Property Value -Descending
$result | Format-Table -Property @{Label = "节点IP"; Expression = { $_.Key }; }, @{Label = "速度"; Expression = { "$($_.Value) MB/s" } }

ForEach ($entry in $result) {
    $line = "$(Get-Date -Format "yyyy-MM-dd") [$($entry.Key)] 下载速度: $($entry.Value) MB/s `r`n`r`n"
    ForEach ($dm in $dms) {
        $line += "$dm`t$($entry.Key)`r`n"
    }
    $line += "`r`n-----------------------------------------------`r`n`r`n"
    Add-Content $report $line
}

"请查看文件夹下 report.txt 获取测速报告及Dnsmasq"
"=================================="
"修改预置CDN请修改telecom.txt（电信）/unicom.txt（联通），修改解析用DNS请修改dnslist.txt"

pause