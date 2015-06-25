param (
	[string] $exportcsv = "",
	[string] $debugmode = ""
)

if ($exportcsv -eq "")
{
	$exportcsv = Read-Host "Export CSV Path";
}

if ($exportcsv -ne "") 
{
	$path = Split-Path -parent $MyInvocation.MyCommand.Definition
	$starttime = (Get-Date -UFormat "%Y_%m_%d_%I_%M_%S_%p").ToString()
	Start-Transcript "$path\Domain_Local_Group_Export_$starttime.txt"

	Write-Host -ForegroundColor green "Exporting domain local groups to -> $exportcsv"

	if ((Get-PSSnapin -Name "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -eq $null)
	{
		Add-PSSnapin "Microsoft.SharePoint.PowerShell"
	}

	$sites = Get-SPSite

	$csvobject = @()

	foreach ($site in $sites) 
	{
		$currentsiteurl = $site.Url
		Write-Host -ForegroundColor green "`r`nStarted crawling SharePoint Site at $starttime with url -> $currentsiteurl"

		foreach ($web in $site.AllWebs)
		{
			if ($web.HasUniqueRoleAssignments)
			{
				foreach ($webroleassignment in $web.RoleAssignments)
				{
					if ($webroleassignment.Member.UserLogin -ne $null -and $debugmode -eq "")
					{
						$aduser = $web.EnsureUser($webroleassignment.Member.UserLogin)
						$isgroup = $aduser.IsDomainGroup

						if ($isgroup)
						{
							$obj = New-Object PSObject -Property @{
								"Type" = "Web"
								"Name" = $web.Title
							  	"SamAccountName" = $webroleassignment.Member
								"Url" = $web.Url
							}

							$csvobject += $obj

							$currentweburl = $web.Url
							Write-Host -ForegroundColor green "`r`nExported $aduser for web -> $currentweburl"
						}
					}
				}
			}

			foreach ($list in $web.Lists)
			{
				if ($list.HasUniqueRoleAssignments)
				{
					foreach ($listroleassignment in $list.RoleAssignments)
					{
						if ($listroleassignment.Member.UserLogin -ne $null -and $debugmode -eq "")
						{
							$aduser = $web.EnsureUser($listroleassignment.Member.UserLogin)
							$isgroup = $aduser.IsDomainGroup

							if ($isgroup)
							{
								$obj = New-Object PSObject -Property @{
									"Type" = "List"
									"Name" = $list.Title
								  	"SamAccountName" = $listroleassignment.Member
									"Url" = $list.ParentWeb.Url + "/" + $list.RootFolder.Url
								}

								$csvobject += $obj

								$currentlisturl = $list.ParentWeb.Url + "/" + $list.RootFolder.Url
								Write-Host -ForegroundColor magenta "`r`nExported $aduser for list -> $currentlisturl"
							}
						}
					}
				}

				$spquery = New-Object Microsoft.SharePoint.SPQuery
				$spquery.ViewAttributes = "Scope='Recursive'"
				$spquery.RowLimit = 2000
				$caml = "<OrderBy Override='TRUE'><FieldRef Name='ID'/></OrderBy>"
				$spquery.Query = $caml 

				do
				{
					$listitems = $list.GetItems($spQuery)
					$spquery.ListItemCollectionPosition = $listitems.ListItemCollectionPosition

					foreach ($listitem in $listitems)
					{
						if ($listitem.HasUniqueRoleAssignments)
						{
							foreach ($listitemroleassignment in $listitem.RoleAssignments)
							{
								if ($listitemroleassignment.Member.UserLogin -ne $null -and $debugmode -eq "")
								{
									$aduser = $web.EnsureUser($listitemroleassignment.Member.UserLogin)
									$isgroup = $aduser.IsDomainGroup

									if ($isgroup)
									{
										$obj = New-Object PSObject -Property @{
											"Type" = "List Item"
											"Name" = $listitem.Name
										  	"SamAccountName" = $listitemroleassignment.Member
											"Url" = $listitem.Web.Url + "/" + $listitem.Url
										}
										
										$csvobject += $obj

										$currentlistitemurl = $listitem.Web.Url + "/" + $listitem.Url
										Write-Host -ForegroundColor yellow "`r`nExported $aduser for list item -> $currentlistitemurl"
									}
								}
							}		
						}
					}
				}
				while ($spQuery.ListItemCollectionPosition -ne $null)
			}

			$web.Dispose()
		}

		$site.Dispose()
	}

	$csvobject | Export-Csv $exportcsv -notype

	Stop-Transcript

	$endtime = (Get-Date -UFormat "%Y_%m_%d_%I_%M_%S_%p").ToString()
	Write-Host -ForegroundColor green "Exporting domain local groups completed at $endtime!"
}