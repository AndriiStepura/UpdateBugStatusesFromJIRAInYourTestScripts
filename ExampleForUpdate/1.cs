        //Open
		[Bug("NAME-1", BugStatus.Open)]
        [Bug("NAME-1", BugStatus.Closed)]
        
		//InProgress
        [Bug("NAME-2", BugStatus.Closed)]
		[Bug("NAME-2", BugStatus.InProgress)]
        [Bug("NAME-2")]
		[Bug("NAME-2", BugStatus.Open)]
				
		//InReview
		[Bug("NAME-3", BugStatus.Closed)]
		
		
		//ReadyToTest
		[Bug("NAME-3", BugStatus.Open)]
		[Bug("NAME-3", BugStatus.Closed)]
		
		//InTest
		[Bug("NAME-4", BugStatus.Open)]
		[Bug("NAME-4", BugStatus.InTest)]

		//Closed
		[Bug("NAME-5", BugStatus.Open)]
		[Bug("NAME-5", BugStatus.InTest)]