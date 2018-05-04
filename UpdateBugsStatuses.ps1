#1. MVP - regexp
#2. DONE - refactor to use not just one dimension arrays {issueNumber, fileToUpdate, oldString, newString}
#3. ToDo - move PLEC as settings variable
#4. ToDo - refactor with remove slleps
#5. DONE - add parameeter for reduce redundant calls to JIRA by off status check if bug in Closed status now

#Set actual cookie and url to JIRA
$JIRAUrl = 'https://jira.--------------.com'
$CurlArgument = '-k', '-X', 'GET',
                '-H', 'cookie: _ga=----------; jira.editor.user.mode=source; atlassian.xsrf.token=----------|-----------------------|---; crowd.token_key=---------------------; JSESSIONID=--------------------'

# Default path to curl with GitBash
$CURLEXE = 'C:\Program Files\Git\mingw64\bin\curl.exe'

# set Your tests folder path
#$Path = "..\..\Tests\V1_0" # relative
$Path = "C:\Artifacts\FullTestRunsReports\CheckStatus\TestsFolder" # full for local script debug

$BugsWithoutStatus = '[\\[]Bug[\\(][\\"]PLEC-(.*)[\\"][\\)][]\\]'
$BugsWithStatus = '[\\[]Bug[\\(][\\"]PLEC-(.*)[\\"], BugStatus.(.*)[\\)][]\\]'
$TestCategoryFailingWithoutBugs = '^[ \t]*[\\[]Category[\\(]TestCategory.Failing[\\)][]\\]' # [Category(TestCategory.Failing)] without bug label

$PathArray = @() # Array with all pathes to our files with tests

# Remove [Category(TestCategory.Failing)] if exists without bug labels
$RemoveTestCategoryFailingWithoutBugs = $true

# set if you want to check also closed statuses
$CheckClosedBugs = $false

# First of all verify is JIRA available and token valid, so lets check:
function CallToJira ($issue){
    sleep 0.5 #better wait, than broot the JIRA

	# Lets learn PowerShell work with curl, here is our small builder with authorisation and request to one bug status          
	$CurlArgumentCurrentBug = $CurlArgument;
    $Url = "${JIRAUrl}/rest/api/2/issue/${issue}?fields=status"
	$CurlArgumentCurrentBug += $Url
	
	#Call JIRA API and save response wich contains issue actual status
	$Response = & $CURLEXE @CurlArgumentCurrentBug
    if($Response -like '*Unauthorized (401)*'){
        echo "==========================================================="
        echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        echo "===!!!!!401 ERROR, CHECK JIRA CurlArgument variable!!!!!==="
        echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        echo "==========================================================="
        pause
        Exit
    }
    if ($Response -like '*renderedFields,names,schema,operations,editmeta,changelog,versionedRepresentations*'){
        #echo "==========================================================="
        #echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        #echo "===!!!!!!!!!JIRA CONNECTION IS OK AND AVAILABLE!!!!!!!!!==="
        #echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        #echo "==========================================================="
    Return $Response
    }
    else
    {
        echo "==========================================================="
        echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        echo "===!!!!!CHECK INTERNET AND VPN Connection to JIRA!!!!!!!==="
        echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        echo "==========================================================="
        pause
        Exit
    }

}

CallToJira('PLEC-1'); 

$BugsWithStatuses = @([pscustomobject]@{})
$BugsWithoutStatuses = @([pscustomobject]@{})
$AllBugsList = @([pscustomobject]@{})

$AllExistedBugsAndTheyStatusesBeeforeUpdate = @{}
$AllExistedBugsAndTheyStatusesAtJira = @{}

# This code snippet remove [Category(TestCategory.Failing)] if exists without bug labels
if($RemoveTestCategoryFailingWithoutBugs){
echo "Lets remove [Category(TestCategory.Failing)] if exists without bug labels"
echo "========================================================================="
Get-ChildItem -recurse $Path -Filter "*.cs" |
Where-Object { $_.Attributes -ne "Directory"} |
	ForEach-Object {
            $tempFilePath = $Path + '\' + $_.Name
		    If (Get-Content $_.FullName | Select-String -Pattern $TestCategoryFailingWithoutBugs -AllMatches)  {
                    $tempFileContent = Get-Content $tempFilePath #Save file content to temporary variable
                    $tempFileContent = $tempFileContent | select-string -pattern $TestCategoryFailingWithoutBugs -notmatch #Remove redundant content from variable
                    $tempFileContent | Set-Content -Encoding UTF8 $tempFilePath
                    }      
                    
			    }
}

# This code snippet gets all matches in $Path that end in ".cs".
echo "Lets create array with all exists bug labels without status"
echo "==========================================================="
Get-ChildItem -recurse $Path -Filter "*.cs" |
Where-Object { $_.Attributes -ne "Directory"} |
	ForEach-Object {
        $TempBugsArray = @() # create array for save current document bugs labels
		    If (Get-Content $_.FullName | Select-String -Pattern $BugsWithoutStatus -AllMatches)  {			
		        $TempBugsArray = Get-Content $_.FullName | Select-String -Pattern $BugsWithoutStatus -AllMatches
                foreach ($bug in $TempBugsArray)
                    {              
            	        $bugNumber = $bug -replace '.*PLEC-(.*)[\\"].*','PLEC-$1';
                        
                        $BugsWithoutStatuses += @([pscustomobject]@{filePath=$_.FullName; bugLabelOld=$bug; bugNumber=$bugNumber; bugStatusOld='NoStatus'; bugStatusNew=''; needUpdate=1})

                        if(!$AllExistedBugsAndTheyStatusesBeeforeUpdate[$bugNumber]){
                        $AllExistedBugsAndTheyStatusesBeeforeUpdate.Add($bugNumber, 'NoStatus')
                        }
                    }
			    }
	}

echo "Lets add to array all exists bugs labels with statuses"
echo "===================================================="
Get-ChildItem -recurse $Path -Filter "*.cs" |
Where-Object { $_.Attributes -ne "Directory"} |
	ForEach-Object {
        $TempBugsArray = @() # create empty array for save current document bugs labels
		    If (Get-Content $_.FullName | Select-String -Pattern $BugsWithStatus -AllMatches)  {			    
			    $TempBugsArray += Get-Content $_.FullName | Select-String -Pattern $BugsWithStatus -AllMatches
                foreach ($bug in $TempBugsArray)
                    {              
                        $bugNumber = $bug -replace '.*PLEC-(.*)[\\"].*','PLEC-$1';
                        $bugStatus = $bug -replace '.*BugStatus.(.*)[\\)].*','$1';
                        
                        $BugsWithStatuses += @([pscustomobject]@{filePath=$_.FullName; bugLabelOld=$bug; bugNumber=$bugNumber; bugStatusOld=$bugStatus; bugStatusNew=''; needUpdate=0})
                       
                        if (!$AllExistedBugsAndTheyStatusesBeeforeUpdate.Contains($bugNumber)){
                                if (!$CheckClosedBugs -and $bugStatus -eq 'Closed'){
                                    # Current bug skipped, according to settings not recheck Closed bugs
                                }
                                else {
                                    $AllExistedBugsAndTheyStatusesBeeforeUpdate.Add($bugNumber, $bugStatus)
                                }
                            }
                    }
			    }
	}

echo "===================================================="	
echo "Old labels:"
$AllExistedBugsAndTheyStatusesBeeforeUpdate | ForEach-Object {$_}


echo "===================================================="
echo "Call JIRA API for receive response which contains actual issues statuses"

$AllExistedBugsAndTheyStatusesBeeforeUpdate.GetEnumerator() | % { 
    #Call JIRA API and save response wich contains issue actual status  
    $actualStatus = CallToJira($_.key)
    #remove all response details, left just issue statuses - (Open)|(In Progress)|(In Review)|(Ready for Test)|(Closed)|(Not Exist)
    $Status = $actualStatus -replace '.*(gif|png)\",\"name\":\"((Open)|(In Progress)|(In Review)|(Ready for Test)|(In Test)|(Closed)|(Not Exist)).*','$2';
    
    #change statuses to enum labels used in nUnit labels
    if($Status -match "Open"){$_.Value = "Open"}
	elseif($Status -match "In Progress"){$_.Value = "InProgress"}
	elseif($Status -match "In Review"){$_.Value = "InReview"}
	elseif($Status -match "Ready for Test"){$_.Value = "ReadyForTest"}
	elseif($Status -match "In Test"){$_.Value = "InTest"}
    elseif($Status -match "Closed"){$_.Value = "Closed"}
	elseif($Status -match "Not Exist"){$_.Value = "NotExist"}
	else{$_.Value = "NotExist"}

    $AllExistedBugsAndTheyStatusesAtJira.Add($_.key, $_.Value)
    }

echo "===================================================="
echo "New labels:"
$AllExistedBugsAndTheyStatusesAtJira | ForEach-Object {$_}

echo "===================================================="
echo "All candidates for update:"
$AllBugsList = $BugsWithoutStatuses+$BugsWithStatuses
$AllBugsList | ForEach-Object {$_}

echo "===================================================="
echo "Update candidates statuses according to current statuses from JIRA:"

$AllBugsList | ForEach-Object {
    $_.bugStatusNew = $AllExistedBugsAndTheyStatusesAtJira[$_.bugNumber]
    if($_.bugStatusNew -ne $_.bugStatusOld){$_.needUpdate = 1}
    if (!$CheckClosedBugs -and $_.bugStatusOld -eq 'Closed'){    
        # Current bug skiped, according to settings not recheck Closed bugs
        $_.needUpdate = 0
    }
}

echo "===================================================="
echo "All records for update:"
$needUpdate = $AllBugsList | Where-Object {$_.needUpdate -eq 1}
$needUpdate

echo "===================================================="
Write-Host "Need update $($needUpdate.Count) of all $($AllBugsList.Count)"

# Lets open each file where our labels for replace and set actual bugs statuses
$needUpdate | Group-Object filePath | ForEach-Object { # for each file where need rewrite bugs statuses
    echo "===================================================="
    $tempFilePath = $_.Name
    
    Write-Host "Open file $($tempFilePath)"        
    #Save file content to temporary variable
    $tempFileContent = Get-Content $tempFilePath
    
    #Update bugs statuses in variable
    $needUpdate | Where-Object {$_.filePath -eq $tempFilePath} | ForEach-Object {
        Write-Host "Need update bug $( $_.bugNumber) replace from $($_.bugLabelOld) for [Bug('$($_.bugNumber)', BugStatus.$($_.bugStatusNew))]"
        $tempFileContent = $tempFileContent.replace($_.bugLabelOld, '        [Bug("'+$_.bugNumber+'", BugStatus.'+$_.bugStatusNew+')]')
    }
    
    # Let's add label [Category(TestCategory.Failing)] for all Open and InProgress bug labels
    $tempFileContent = $tempFileContent.replace('BugStatus.Open)]', 'BugStatus.Open)][Category(TestCategory.Failing)]')
    $tempFileContent = $tempFileContent.replace('BugStatus.InProgress)]', 'BugStatus.InProgress)][Category(TestCategory.Failing)]')

    #Overwrite file with temporary variable which contains updated statuses
    #by reason of sporadically fails with error "Set-Content : Stream was not readable.", add 
    sleep 3 #TODO remove this wait
    $tempFileContent | Set-Content -Encoding UTF8 $tempFilePath
    sleep 1 #TODO remove this wait  
}

# Finish
        echo "==========================================================="
        echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        echo "===!!!!Finish all statuses are updated - GIT PUSH it!!!!==="
        echo "===!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!==="
        echo "==========================================================="
pause