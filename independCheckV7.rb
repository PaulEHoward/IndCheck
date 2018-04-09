# This is part of a 'Git' experiment so everything here can be ignored.  What I'm thinking of
# doing is to replace arrays by hashes for data from the potentialbiggie file.


# Note120Calculations.rb - a modification of IndependCheckV7.rb designed to write the
# form_model_cores derivable from note 120 or note 2.  We'll read from the same files
# as IndependCheckV7.rb and write to N120form_model_cores.out
#################                                                                                               # IndependCheckV7.rb  # 
#################
# 8/5/15  V7 now writes to the file form-model.dat in the form described below. It also,
# rather than reading book1 into the array b1, the program creates the array b1 of positive
# implications from Rfb1.dat.  This program also writes the results to the file modelTrsFrms.out 
# which really looks better since the models are separated.  Also, it's a little condensed so it
# has fewer lines.  Probably should eliminate one output file.
# V7 saves more in the file "form-model.dat"  for forms with a reference it saves
#              HR-no     modelName   T/F     Reference    
#    for forms derivable from note-120 or note-2 it saves
#                 HR-no     modelName   T/F     Note-120/Note-2   Reason (in some form)
#    for forms that follow from true forms
#                 HR-no     modelName     T       relavantImplication
#    for forms which imply false forms
#                 HR-no      modelName     F       relavant implication
# Maybe four files should be used.
# The files V7 needs:  Rfb1.dat, N120.dat, N2.dat, transferable.dat, negationNotTrans.dat, pbText.csv.
#  
# V6 saves the form-model data in a more "data file" like data file called "form-model.dat".
# V5 is identical to V4 except that when reading the file N120.dat, if there is a "*" following the number
# in column 5 (the HR# of the conclusion) then the line is interpreted to mean
# that the HR#s in columns "hyp. 1" and "hyp. 2" are 
# numbers of forms at least one of which must be true.   For example line 24 in N120.dat
# V4 is identical to V3 except that it's able to read the two files with the absolutely transferable forms
# (transferable.dat) and with the forms whose negation may not be transferable (negationNotTrans.dat)
# even if the HR-number in each row is followed by a reference in each row and if there are comments at
# the beginning starting with any non-digit, non-space character.
# independCheck.rb and independCheckV2.rb didn't get all the non-implications.
# the reason is that the following may occur for a given model M:  A true in M with a ref., B false in M with
# a reference, A not transferable, the negation of B not transferable, A implies C and C transferable, D implies 
# B and D negation-transferable and (finally) C implies E and F implies D.  Under these circumstances 
# the non-implication "E not imply F" transfers because "C not imply D" does.  

# General Plan:  Using potentialbiggie create a matrix independ similar to book1 but with only the 
# non-implications codes (deducible from potentialbiggie).    Then, for each non-implication code in book1
# (3, 4, 5 or 6), check to see if the same (or stronger) code occurs at the same position in indpend.

# (11/22/2014) Then check, for each non-implication code in rfb1 (using the file rfb1.dat) whether the same or
# a stronger code occurs at the corresponding position in independ

# Some Details:  Read lines from the file pbText.csv (which is a version of potentialbiggie) and use these lines, 
# (other than those whose reference is note-2 or note-120) together with notes 2 and 120 (as contained in the
# files N2.dat and N120.dat) to generate, for each model, a list of additional forms that are true in the model and a list
# of additional forms that are false in the model.  Using the lines from pbText.csv and the list of true forms and 
# the list of false forms that are generated, add entries to independ.
# 
#
# N2.dat and N120.dat are (crude) data files with columns headed
#       line#	hyp. 1	hyp. 2	hyp. 3	conc	reference 
# (Non-data lines begin with #).  The files contain one line for each row of Note 2 and Note 120 respectively.
#
# pbTex.csv has columns headed 
#   model_id # form_id # * # Form Number # reference_type # model_tex_name # FormNumber # form_statement # 
#   reference_slug # optional # true_or_false # trans # neg-trans
# with the symbol # as a column separator.
################################################################################

                                            ######################################################
                                            # Initial Stuff:  Reading in data files, opening output files and preparing other #
                                            #                                                     data                                                                              #
                                            ######################################################

require 'set'                                                                    
# To get the array im we'll read the code1s from Rfb1.dat (file handle rf) and the references
# im[m][n] will be a two element array, im[m][n][0] will contain the implication code 1 if 
# HR m implies HR n and im[m][n][1] will contain the reference.  Later we'll calculate the code2s
# Then b1 will be an array with just the code1s and code2s (no references).  
b1 = Array.new
im = Array.new              #  im will contain the code1 and code2 implications.  (a '1' or a '2' at positon
                                                                        # (m,n) if form m implies form n).
 rf = File.open("Rfb1.dat")        # Rfb1.dat is rfb1 with lines of the form "hyp#   conc#   (code)   reference(s)"

               # Step 1:  read the file Rfb1.dat into the array im (code1s only) and get the max form number #
                 # Step 1A:  Get the largest form number occuring in Rfb1.dat

maxFormNo = 0            # We'll store the the largest HR form number in maxFromNo    
rf.each_line do |line|   # First find the largest form number
  if m = line.match(/\s*(\d+)\s*(\d+)\s*\((\d)\)\s*(.*)/) # We're  looking for a line in Rfb1.out like  "185   10  (3)  (N6T)"
	i = m[1].to_i  # put the first form number (185 in the example above) into i
    j = m[2].to_i  # and the second (10) into j
    maxFormNo = [maxFormNo, i, j].max
  end
end    

                 #  Step 1B Read in N2.dat and N120.dat and increase maxFormNo if necessary
                 #  (This is the data from notes 2 and 120.)

# Read the file N120.dat into the array n120.  The lines of N120.dat have the form
#    line#   hyp. 1    hyp. 2    hyp. 3   conc   reference
#  where line# is the line from Note 120, hyp.1, hyp.2 and hyp.3 are form numbers of hypotheses
#  conc is the form number of the conclusion and reference is a reference for the implication
#      hyp.1 + hyp.2 + hyp.3 implies conc
#  Note: hyp.2 and/or hyp.3 may be 0
# UNLESS the conclusion (conc) is followed by a "*" in which case we interpret hyp. 1 and hyp. 2 
# as form numbers of forms at least one of which must be true.

n120 = Array.new
note120 = File.open("N120.dat")
i = 0                          #index for the rows of the array n120
note120.each_line do |line|
   line = line.chomp  #eliminated the new line stuff at the end of each line 
   if tem = line.match(/\A\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)\s*(\**)/)  #if the line has 5 digits separated by 
                                                                              # space, capture  the digits in 
                                                                                                                    # tem.captures
      tem2 = tem.captures                                # put the captured integer strings into tem2
      tem2.each.with_index do |t,i|                      # change the string entries to integer
         if t.match(/\A\d+/)
            tem2[i] = t.to_i
         end
      end
      maxFNthisLine = [tem2[1],tem2[2],tem2[3],tem2[4]].max  #The maximum form number in this row
      if maxFNthisLine > maxFormNo
        maxFormNo = maxFNthisLine                            # Replace maxFornNo if necessary
      end
      n120[i] ||= tem2                                          # and put the integers into row i of n120 along with the "*" if it's 
                                                                             # there.  If it is it will be in n120[i][5]
      i = i +1                                                           # increment the row number
   end   
end
note120.close

# Now read N2.dat into the array n2 in a similar way

n2 = Array.new
note2 = File.open("N2.dat")
i = 0                          #index for the rows of the array n2
note2.each_line do |line|
  line = line.chomp  #eliminated the new line stuff at the end of each line 
  if tem = line.match(/\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)\s*(\d+)/)  #if the line has 5 digits separated by 
                                                                                                                   # space capture the digits in 
                                                                                                                    # tem.captures
      tem2 = tem.captures                           # put the captured strings into tem2
      tem2 = tem2.map{|it| it.to_i}                  # change to integer
      maxFNthisLine = [tem2[1],tem2[2],tem2[3],tem2[4]].max  #The maximum form number in this row
      if maxFNthisLine > maxFormNo
        maxFormNo = maxFNthisLine                            # Replace maxFornNo if necessary
      end     
      n2[i] ||= tem2                                         # and put the integers into row i of n2
      i = i +1                                                           # increment the row number
  end   
end
note2.close

             # End of reading in note-2 and note-120 (into the arrays n2 and n120). 


               # Initialize the array im to avoid the undefined method errors

(0..maxFormNo).each do |i|
  im[i] = Array.new 
    (0..maxFormNo).each do |j|
        im[i][j] = [0, 0]
    end    
end   
print "#{maxFormNo}\n"     #diagnostic
rf.rewind

rf.each_line do |line| 
  if m = line.match(/\s*(\d+)\s*(\d+)\s*\((\d)\)\s*(.*)/) # We're  looking for a line in Rfb1.out like  "185   10  (3)  (N6T)"
	i = m[1].to_i  # put the first form number (185 in the example above) into i
    j = m[2].to_i  # and the second (10) into j
    if m[3] == "1"   # we want to use only the code1s
       im[i] ||= []   # initialize im[i] as an empty array if it hasn't been initialized yet
	   im[i][j] ||= []  #We'll put two things here, the implication code and the reference info.
       im[i][j][0] = m[3].to_i # put the implication code (3 in the example) into im[i][j][0]
       im[i][j][1] = m[4].chomp   #And now the reference for position i,j goes in im[i][j][1].
    end
  end
end

# Still part of initial stuff, get the set of absolutely transferable forms ($transferableS) and the set of forms whose negations
# are absolutely transferable ($negationTransS) and make them global.  This is not absolutely necessary for the present calculation
# but may be useful later.
transferableF = File.open("transferable.dat")    # the file with a list of transferable forms
negationNotTransF = File.open("negationNotTrans.dat")    # file with forms whose negation isn't transferable
$transferableS = Set.new                                     # these are the sets corresponding to 
negationNotTransS = Set.new                          # the files
                                                                                 # populate the sets
transferableF.each do |line|
   if m = line.match(/\A\s*(\d+)/)                    # if the line has any space followed by some digits at the beginning
      form = m[1].to_i
     $transferableS << form
   end
end

negationNotTransF.each do |line|
   if m = line.match(/\A\s*(\d+)/)
      form = m[1].to_i
      negationNotTransS << form
   end
end
allFormsS = Set.new(0..maxFormNo)     # the set of all forms (I.e., HR-form numbers)    
$negationTransS = allFormsS - negationNotTransS     # the set of forms whose negation is (absolutely) transferable



                 # Step 2:  Insert 1s at positions (n,n), (1,n) and (n,0) and 0s at other positions.

(0..maxFormNo). each do |n|
   im[n] ||= Array.new
   (0..maxFormNo).each do |m|
      im[n][m] ||= Array.new
      im[n][m][0] ||= 0
   end
end
(0..maxFormNo).each do |n|   
   im[n][n][0] = 1
   im[n][n][1] ||= "clear"
   im[1][n][0] = 1
   im[1][n][1] ||= "to be added"
   im[n][0][0] = 1
   im[n][0][1] ||= "clear"
end  

                     # Step 3:  Close the array under implication (i.e., add the code2s) #  

# The plan is to look at each HR form number hyp.  Starting with the hypotheses (hyp) we will calculate an
# array of sets hypAr.  hypAr[0] = { [hyp] } and hypAr[n+1] = { [hyp, f1, ..., fn, f_{n+1}] :  [hyp, f1, ..., fn] \in hypAr[n] and
# im[fn][f_{n+1}][0] = 1  and f_{n+1} has not occurred as a consequence of hyp in hypAr[k] for k < n+1}.  Then for each 
# string [hyp, f1, ..., fn, f_{n+1}] in hypAr[n+1] we add a code2 at position (hyp,f_{n+1}) of im and we add f_{n+1} to 
# the set alreadyIn.   
# 
# We'll stop when we find an array [hyp, f1, ..., fn, f_{n+1}] where f_{n+1} = conc if this happens.
# Then we set im[hyp][conc][0] = 2 and im[hyp][conc][1] = [hyp, f1, ..., fn, conc].  If this never happens we go on 
# to the next pair (hyp, conc).

(0..maxFormNo).each do |hyp|                     # for each hypothesis
   alreadyIn = Set.new                           # the set of consequences of hyp that we already have
   alreadyIn << hyp                                 # initialize it to the hypothesis (hyp).
   im[hyp] ||= Array.new                        # we'll be adding code2s in row hyp of im
   hypAr = Array.new                                # this will be an array of sets (of arrays)
   hypAr[0] = Set.new                               # hypAr[0] is a set containing just the array [hyp]
   hypAr[0] << [hyp]                                       #
   n = 0                                                         # the index for hypAr
   while  !(hypAr[n].empty?)    # When hyperAr[n] is empty we've checked all possible paths from hyp
      hypAr[n+1] = Set.new
      hypAr[n].each do |impstr|                # We're thinking of the arrays in hypAr[n] as implication strings.
         (2..maxFormNo).each do |posconc|  # We'll check each form to see if the last form in impstr implies it (code1).
            if(  !alreadyIn.member?(posconc) && im[impstr.last] && im[impstr.last][posconc] && im[impstr.last][posconc][0] == 1  )                     # if the last item in the implication
                                                                                 # string implies posconc, then
               newimpstr = impstr + [posconc]
               hypAr[n+1] << (newimpstr)  # add posconc to the implication string and insert in hypAr[n+1].
               conc = posconc                           # our possible conclusion is deducible from hyp (but that's no reason for using "conc")
               alreadyIn << conc
               im[hyp][conc] ||= Array.new
                if im[hyp][conc][0] != 1
                  im[hyp][conc][0] = 2                # if the value in im[hyp][conc][0] is not already 1, set it to code2
               end
               im[hyp][conc][1] ||= newimpstr      # put in the code1 string from hyp to conc - note: posconc has been added to impstr
#               print " hyp #{hyp}, conc #{conc}, code #{im[hyp][conc][0]}, str #{im[hyp][conc][1]}\n"             ### diagnostic
            end
         end
      end
      n = n + 1                                             # increase hypAr index            
   end                                                          # "while foundConc ..." loop exits automatically if foundConc != 0
end

     ######################################################################
     # Now we transfer the codes (only) from im to b1                     #
     ######################################################################
     #  (First initialize b1)
     
     
(0..maxFormNo).each do |i|
  b1[i] = Array.new
  (0..maxFormNo).each do |j|
    b1[i][j] = im[i][j][0]
  end
end

# SECONDLY, initialize the array independ
numberOfForms = maxFormNo + 1                               #  the number of forms 
independ =Array.new(numberOfForms)
i = 0
while i < numberOfForms                                 # independ is a numberOfForms by numberOfForms array
   independ[i] =Array.new(numberOfForms){|z| 0}   # independ[i] is an array of size numberOfForms initialized to zeros
   i = i + 1
end


# FOURTH, open some files for printing
   # first the (more) human readable file with the model form information
$diagnosticfile = File.new("modelTrsFrms.out", "w")             # diagnostic (these lines were originally  diagnostic but
y = $transferableS.to_a                                                                 # diagnostic (they've been so useful I'm leaving them in)
$diagnosticfile.print "Absolutely Transferable Forms: #{y}\n\n"  # diagnostic
  # second the more "data file' like file form-model.dat
$form_model = File.new("./data/form-model.dat","w")


# open the version of potentialbiggie with "#" as column separators
if (pb = File.open("pbText.csv"))  
   print "found file \n"                        # This is the input file with the model info
end

                        #############
                        # The output file #
                        #############
modfile = File.new("ProblemNonImps.out","w")             # open a file for the output
   ######## note that there is a second output file $diagnosticfile (opened above) which
   ######## outputs the model information model by model.                    

###############################################
#                                           End initial stuff                                                  #
###############################################

###############################################
#                                                 The Plan                                                        #
###############################################

# Read the file pbText.csv.  We'll
#   1.  Read the first and second lines.  (The first line has the headings, the second begins the data.)
#   2.  Continue reading and processing lines until the model number changes storing true forms and
#         and false forms with a reference
#   3.  Add (and write) the note 18 forms (this is for a later version of the program)
#   4.  Enter a "3" or "5" in independ at positions A,B where A is true in the model and B is false and 
#         both have references
#   5.  Add (and write) the forms that follow from notes 120 and 2 if appliicable
#   6.  Add "4" or "6" to independ at new positions A,B where A is true in the model and B is false.
#   7.  Continue with the next model

tfa = Array.new                                                  # arrays to hold the true forms and false forms from a model

#  3/18 Replacement line tfa = Hash.new

ffa = Array.new

#  3/18 Replacement line ffa = Hash.new

###########################################################
#    Methods for updatind tfa and ffa using n120 and n2  and for updating independ  #
###########################################################

###################### tfa.note2check #######################

def tfa.note2check(b1,n2,modelid,modelname)
  # b1 is the implication/non-implication matrix as an array of integer arrays
  # n2 is note-2 as an array of arrays
  # modelid is the model id number (string)
  # modelname is the complete model name as a string

  # First decide whether the hypotheses are true, if so the conclusion is true (in the model)
   n2.each do |n2row|                         # for each row of note-2
      flag = 0
      reason = ""
      [1, 2, 3].each do |hypno|              # check the three hypotheses
         n = 0
         flag = 0
         while n < self.size                        # to see if any of the true form implies them
            if( (b1[self[n][0]][n2row[hypno]] == 1) || (b1[self[n][0]][n2row[hypno]] == 2) )
               if !(n2row[hypno] == 0) 
                  if !(self[n][0] == n2row[hypno])
                     reason = reason<<" #{self[n][0]} is true and #{self[n][0]} implies #{n2row[hypno]} so "
                  end
                  reason << "#{n2row[hypno]} is true .  "
               end 
               n = self.size    
               flag = 1                 
            else
               n = n + 1   
            end
         end
         if flag == 0 
            break
         end
      end 
      if(flag==1)
         reason = reason<<"By Note 2, part #{n2row[0]}, #{n2row[1]} "
         if n2row[2] != 0
            reason = reason << "+ #{n2row[2]} "
         end
         if n2row[3] != 0
            reason = reason << "+ #{n2row[3]} "
         end
         reason = reason << "implies #{n2row[4]} in all FM models so #{n2row[4]} is true."
         iflag = 1                                 # value 1 if n2row[4] in not implied by any of the true forms
         self.each do |tf|                     # a quick check to make sure n3row[4] is not already implied by one of the true forms
            if (( b1[tf[0]][n2row[4]] == 1) || (  b1[tf[0]][n2row[4]] ==2))
               iflag = 0
            end
         end
         if iflag == 1
            if n2row[4] < 383                                      #calculate the formid from the HR formno
                formid = n2row[4] + 25
            else
               formid = n2row[4] +24
            end
            trans = "unknown"                                      # checck the transferability of the form and it's negation
            transneg = "unknown"                               # initialize both to "unknown"
            if $transferableS.include?(n2row[4])
               trans = "transferable"
            end
            if $negationTransS.include?(n2row[4])
               transneg = "negation transferable"
            end
            self[self.size] ||= [n2row[4], modelid.to_i,  formid.to_i, "calculated", reason," ", modelname, "true", \
                                           trans, transneg ]       
                                                                                                                                                           # add the conclusion of the row 
                                                                                                                                                           # to the list of true forms
         end
      end 
   end
end                                                              # tfa.note2check


############################# tfa.note120check ############################

def tfa.note120check(b1,n120,modelid, modelname,ffa)
  # b1 is the implication/non-implication matrix as an array of integer arrays
  # n120 is note-120 as an array of arrays
  # modelid is the model id number (string)
  # modelname is the complete model name as a string
  # ffa is the array of forms false in the model

n120.each do |n120row|                         # for each row of note-120

# First handle the case where the row of N120 represents two forms at least one of which is false.
   if n120row[5] == "*"                             # this is the case where at least one of n120row[1] and n120row[2]  
      ffa.each do |falseform|                      # must be false

         if b1[n120row[1]][falseform[0]] == 1 || b1[n120row[1]][falseform[0]] == 2   # if n120row[1] is false
            if n120row[2] < 383                                      # calculate the formid from the HR formno
                formid = n120row[2] + 25                       # for n120row[2] which must be true
            else
               formid = n120row[2] +24
            end
            reason = "Form #{n120row[1]} is false.  By note-120, part #{n120row[0]} the negation of \
                               #{n120row[1]} implies #{n120row[2]} so #{n120row[2]} is true."
            trans = "unknown"                                      # checck the transferability of the form and it's negation
            transneg = "unknown"                               # initialize both to "unknown"
            if $transferableS.include?(n120row[2])
               trans = "transferable"
            end
            if $negationTransS.include?(n120row[2])
               transneg = "negation transferable"
            end            
            iflag = 1                                 # value 1 if n120row[2] in not implied by any of the true forms
            self.each do |tf|                     # a quick check to make sure n3row[2] is not already implied by one of the true forms
               if (( b1[tf[0]][n120row[2]] == 1) || (  b1[tf[0]][n120row[2]] ==2))
                  iflag = 0
               end
            end
            if iflag == 1
               self[self.size] ||= [n120row[2], modelid.to_i,  formid.to_i, "calculated", reason, "note-120, part #{n120row[0]}",\
                                            modelname, "true", trans, transneg ]         #V7 inserted "note-120, etc"
            end
         end

         if b1[n120row[2]][falseform[0]] == 1 || b1[n120row[2]][falseform[0]] == 2   # similarly  if n120row[2] is false
            if n120row[1] < 383                                      # calculate the formid from the HR formno
                formid = n120row[1] + 25                       # for n120row[1] which must be true
            else
               formid = n120row[1] +24
            end
            reason = "Form #{n120row[2]} is false.  By note-120, part #{n120row[0]} the negation of \
                               #{n120row[2]} implies #{n120row[1]} so #{n120row[1]} is true."
            trans = "unknown"                                      # checck the transferability of the form and it's negation
            transneg = "unknown"                               # initialize both to "unknown"
            if $transferableS.include?(n120row[1])
               trans = "transferable"
            end
            if $negationTransS.include?(n120row[1])
               transneg = "negation transferable"
            end
            iflag = 1                                 # value 1 if n120row[1] in not implied by any of the true forms
            self.each do |tf|                     # a quick check to make sure n3row[1] is not already implied by one of the true forms
               if (( b1[tf[0]][n120row[1]] == 1) || (  b1[tf[0]][n120row[1]] ==2))
                  iflag = 0
               end
            end
            if iflag == 1            
               self[self.size] ||= [n120row[1], modelid.to_i,  formid.to_i, "calculated", reason,  "note-120, part #{note120row[0]}", modelname, "true",  trans, transneg ]     #V7 inserted "note-120, etc"    
            end
         end

      end

# Second the case of an ordinary row of N120
   else
      flag = 0 
      reason = ""
      reasoncode = []                            # V7 - this will be an array [A-h1, B-h2, C-h3, note-120-k]
                                                               # where note 120, part k is h1+h2+h2 \to c, AB&C are T in 
                                                               # the model and A implies h1, etc.
      [1, 2, 3].each do |hypno|              # check the three hypotheses
         n = 0
         flag = 0
         while n < self.size                        # to see if any of the true form implies them
            if( (b1[self[n][0]][n120row[hypno]] == 1) || (b1[self[n][0]][n120row[hypno]] == 2) )
               if !(n120row[hypno] == 0) 
                  if !(self[n][0] == n120row[hypno])
                     reason = reason<<" #{self[n][0]} is true and #{self[n][0]} implies #{n120row[hypno]} so "
                     reasoncode<< "#{self[n][0]}-#{n120row[hypno]}"    # V7 - see reasoncode above
                  end
                  reason << "#{n120row[hypno]} is true .  "
               end 
               n = self.size    
               flag = 1  
               
            else
               n = n + 1   
            end
         end
         if flag == 0 
            break
         end
      end 
      if(flag==1)
         reason = reason<<"By Note 120, part #{n120row[0]}, #{n120row[1]} "
         if n120row[2] != 0
            reason = reason << "+ #{n120row[2]} "
         end
         if n120row[3] != 0
            reason = reason << "+ #{n120row[3]} "
         end
         reason = reason << "implies #{n120row[4]} so #{n120row[4]} is true."
         iflag = 1                                 # value 1 if n120row[4] in not implied by any of the true forms
         self.each do |tf|                     # a quick check to make sure n3row[4] is not already implied by one of the true forms
            if (( b1[tf[0]][n120row[4]] == 1) || (  b1[tf[0]][n120row[4]] ==2))
               iflag = 0
            end
         end
         if iflag == 1
               if n120row[4] < 383                                      #calculate the formid from the HR formno
                   formid = n120row[4] + 25
               else
                  formid = n120row[4] +24
               end

               trans = "unknown"                                      # checck the transferability of the form and it's negation
               transneg = "unknown"                               # initialize both to "unknown"
               if $transferableS.include?(n120row[4])
                  trans = "transferable"
               end
               if $negationTransS.include?(n120row[4])
                  transneg = "negation transferable"
               end
               self[self.size] ||= [n120row[4], modelid.to_i,  formid.to_i, "calculated", reason," ", modelname, "true", \
                                              trans, transneg ]       
                                                                                                                                                           # add the conclusion of the row 
                                                                                                                                                           # to the list of true forms

         end
      end 
   end
end
if self.size == 0                                                               # in case there are no forms known to be true add form 0
   self[self.size] = [0, modelid.to_i, 25, "True in all models", ""," ", modelname,"true","transferable", "negation transferable"]
end
end                                                # tfa.note120check


####################### ffa.note2check ####################################

def ffa.note2check(b1,n2,tfa,modelid, modelname)
  # b1 is the implication/non-implication matrix as an array of integer arrays
  # n2 is note-2 as an array of arrays
  # modelid is the model id number (string)
  # modelname is the complete model name as a string

  # check to see if all but one of the hypotheses are true and the conclusion is false.
  # If so then the remaining hypothesis must be false.
n2.each do |n2row|                          #for each row in the file note-1
   concfflag = 0;                                 # start with the assumption that the conclusion of row n2row is true
   hypflag = [0,0,0,0]                         # and that the hypotheses are all false.  (We won't use hypflag[0].)
   reason = ""                                 # This will eventually be the string to be output for row n2row
   n = 0 
   while n < self.size                           # n is the index of one of the forms which is false in the model
      if( (b1[n2row[4]][self[n][0]] == 1) || (b1[n2row[4]][self[n][0]] == 2) )    # If the conclusion of line n2row implies false form n
         concfflag = 1                           # conclusion is false
         if self[n][0] == n2row[4]              # add a sentence to "reason"
            reason << "#{n2row[4]} is false. "
         else
            reason << "#{self[n][0]} is false and #{n2row[4]} implies #{self[n][0]} so #{n2row[4]} is false.   "  
         end                                           # if ... else ...
         n = self.size                               # and make sure this is the last iteration of the  "while n < ffa.size"
      else
         n = n + 1                                     # otherwise try the next false form
      end                                                # if ... else ...
   end                                                   # while n < self.size
   if concfflag == 0                            # if we haven't found that the conclusion is false
      next                                               # go to the next line of note-2
   end

   [1,2,3].each do |hypno|                 # If we found the conclusion is false check each hypothesis
      n = 0                                              # initialize true form counter
      while n < tfa.size                         # for each form true in the model
         if( (b1[tfa[n][0]][n2row[hypno]] == 1 ) || (b1[tfa[n][0]][n2row[hypno]] == 2 ) )  # if the nth true form implies hypothesis
                                                                                                                                            # number hypno   
            hypflag[hypno] = 1                        #  we note that hypothesis n is true
            if tfa[n][0] == n2row[hypno]            # add a sentence to reason
               reason = reason << "  #{n2row[hypno]} is true. "
            else
               if n2row[hypno] != 0         # to eliminate "A is true an A implies 0 so 0 is true"
                  if !(tfa[n][0] == n2row[hypno])
                     reason = reason<<" #{tfa[n][0]} is true and #{tfa[n]}[0] implies #{n2row[hypno]} so "
                  end
                   reason = reason << "#{n2row[hypno]} is true .  "
               end
            end                                          # if ... else ...
            n = tfa.size                             # so that we'll exit the "while"
         else
            n = n + 1                                 # otherwise check the next true form
         end                                             # if ....  else ....
      end                                                # while
   end                                                   # [1,2,3].each
   hyptsum = hypflag[1] + hypflag[2] + hypflag[3]     # The number (out of three) of true hypotheses
   if hyptsum != 2                               # we'll print a line if exactly 2 of the hypotheses are true
      next                                               # if not go to the next line of note-2
   else                                                   # on the other hand if exactly 2 hypotheses are true
      mustbf = 0
      [1,2,3].each do |hypno|              # find the false one and put (it's number) in mustbf
         if hypflag[hypno] == 0 
            mustbf = n2row[hypno]
         end                                              # if
      end                                                  # [1,2,3].each
         reason = reason << "By Note 2, part #{n2row[0]}, #{n2row[1]} "
         if n2row[2] != 0
            reason = reason << "+ #{n2row[2]} "     # we don't want form 0 listed
         end
         if n2row[3] != 0
            reason = reason << "+ #{n2row[3]} "      # ditto
         end
         reason = reason << "implies #{n2row[4]} in all FM models so #{mustbf} is false. "          #finish up the line to be printed
   end                                                     # if ... else ...
   iflag = 1                                 # value 1 if mustbf implies any of the false forms
   self.each do |tf|                     # a quick check to make sure n3row[4] is not already implied by one of the true forms
      if (( b1[mustbf][tf[0]] == 1) || (  b1[mustbf][tf[0]] ==2))
         iflag = 0
      end
   end
   if iflag == 1
        if mustbf < 383                                      #calculate the formid from the HR formno
             formid = mustbf + 25
         else
            formid = mustbf +24
         end

          trans = "unknown"                                      # checck the transferability of the form and it's negation
          transneg = "unknown"                               # initialize both to "unknown"
          if $transferableS.include?(mustbf)
             trans = "transferable"
          end
          if $negationTransS.include?(mustbf)
             transneg = "negation transferable"
          end
          self[self.size] ||= [mustbf, modelid.to_i,  formid.to_i, "calculated", reason, " ", modelname, "false", \
                                           trans, transneg ]       
                                                                                                                                                           # add the conclusion of the row 
                                                                                                                                                           # to the list of false forms

   end
end                                                        # n2.each
end                                                        # ffa.note2check


######################### ffa.note120check #####################################

def ffa.note120check(b1,n120,tfa, modelid, modelname)
  # b1 is the implication/non-implication matrix as an array of integer arrays
  # n120 is note-120 as an array of arrays
  # tfa is the array of forms true in the model
  # modelid is the model id number (string)
  # modelname is the complete model name as a string

  # check to see if all but one of the hypotheses are true and the conclusion is false
  # if so then the remaining hypothesis must be false
n120.each do |n120row|                          #for each row in the file note-1
# (note that lines which contain two forms in n120row[1] and n120row[2], one of which must be true will
# be skipped since we enter a zero in the "conc" column - n120row[4].)
   concfflag = 0;                                 # start with the assumption that the conclusion of row n120row is true
   hypflag = [0,0,0,0]                         # and that the hypotheses are all false.  (We won't use hypflag[0].)
   reason = ""                                 # This will eventually be the string to be output for row n120row
   n = 0 
   while n < self.size                           # n is the index of one of the forms which is false in the model
      if( (b1[n120row[4]][self[n][0]] == 1) || (b1[n120row[4]][self[n][0]] == 2) )  # If the conclusion of line n120row 
                                                                                                                                           # implies false form n
         concfflag = 1                           # conclusion is false
         if self[n][0] == n120row[4]              # add a sentence to "reason"
            reason << "#{n120row[4]} is false. "
         else
            reason << "#{self[n][0]} is false and #{n120row[4]} implies #{self[n][0]} so #{n120row[4]} is false.   "  
         end                                           # if ... else ...
         n = self.size                               # and make sure this is the last iteration of the  "while n < ffa.size"
      else
         n = n + 1                                     # otherwise try the next false form
      end                                                # if ... else ...
   end                                                   # while n < self.size
   if concfflag == 0                            # if we haven't found that the conclusion is false
      next                                               # go to the next line of note-120
   end

   [1,2,3].each do |hypno|                 # If we found the conclusion is false check each hypothesis
      n = 0                                              # initialize true form counter
      while n < tfa.size                         # for each form true in the model
         if( (b1[tfa[n][0]][n120row[hypno]] == 1 ) || (b1[tfa[n][0]][n120row[hypno]] == 2 ) )  # if the nth true form implies hypothesis
                                                                                                                                            # number hypno   
            hypflag[hypno] = 1                        #  we note that hypothesis n is true
            if tfa[n][0]== n120row[hypno]            # add a sentence to reason
               reason = reason << "  #{n120row[hypno]} is true. "
            else
               if n120row[hypno] != 0         # to eliminate "A is true an A implies 0 so 0 is true"
                  reason = reason << " #{tfa[n][0]} is true and #{tfa[n][0]} implies #{n120row[hypno]} so #{n120row[hypno]} is true. "
               end
            end                                          # if ... else ...
            n = tfa.size                             # so that we'll exit the "while"
         else
            n = n + 1                                 # otherwise check the next true form
         end                                             # if ....  else ....
      end                                                # while
   end                                                   # [1,2,3].each
   hyptsum = hypflag[1] + hypflag[2] + hypflag[3]     # The number (out of three) of true hypotheses
   if hyptsum != 2                               # we'll print a line if exactly 2 of the hypotheses are true
      next                                               # if not go to the next line of note-120
   else                                                   # on the other hand if exactly 2 hypotheses are true
      mustbf = 0
      [1,2,3].each do |hypno|              # find the false one and put (it's number) in mustbf
         if hypflag[hypno] == 0 
            mustbf = n120row[hypno]
         end                                              # if
      end                                                  # [1,2,3].each
         reason = reason << "By Note 120, part #{n120row[0]}, #{n120row[1]} "
         if n120row[2] != 0
            reason = reason << "+ #{n120row[2]} "     # we don't want form 0 listed
         end
         if n120row[3] != 0
            reason = reason << "+ #{n120row[3]} "      # ditto
         end
         reason = reason << "implies #{n120row[4]} so #{mustbf} is false. "          #finish up the line to be printed
   end                                                     # if ... else ...
   iflag = 1                                 # value 1 if n2row[4] in not implied by any of the true forms
   self.each do |tf|                     # a quick check to make sure mustbf does not imply any of the false forms
      if (( b1[mustbf][tf[0]] == 1) || (  b1[mustbf][tf[0]] ==2))
         iflag = 0
      end
   end
   if iflag == 1
     if mustbf < 383                                      #calculate the formid from the HR formno
          formid = mustbf + 25      
       else
            formid = mustbf +24
      end

       transf = "unknown"                                      # checck the transferability of the form and it's negation
       transneg = "unknown"                               # initialize both to "unknown"
       if $transferableS.include?(mustbf)
          transf = "transferable"
       end
       if $negationTransS.include?(mustbf)
          transneg = "negation transferable"
       end
       self[self.size] ||= [mustbf, modelid.to_i,  formid.to_i, "calculated", reason, " ", modelname, "false", \
                                        transf, transneg ]       
                                                                                                                                                        # add the conclusion of the row 
                                                                                                                                                        # to the list of false forms

   end                                                   # if iflag ==1
end                                                        # n120.each
end                                    #definition  of ffa.note120check

######################## repby(a,b) ######################################

# to determine in the "non-implication" code a should be replaced by the (better) non-implication code b
# repby returns the better code
def repby(a,b)
   if ( b != 0) && (a == 0 || b < a)                      # just checks to make sure b is a better code than a
      return b
   else
      return a
   end
end

######################## independ.update #################################

# Uses tfa, ffa and b1 to update the the array independ with the info from one model
def independ.update(tfa,ffa,b1, modelid, modelprefix,modelnumber,modelsuffix)
   numberOfForms = b1.size                         #  the number of forms (from book1)
   btfS = Set.new                                             # btfS will be the set of (basic) true forms from tfa
   bffS = Set.new                                             # bffS will be the set of (basic) false forms from ffa
reftypeH = Hash.new                                 # we also need a hash to store the reference type of each
                                                                           # of the forms above
   tfa.each do |f|                                         # populate btfS and reftypeH
      btfS << [f[0], f[3], f[4]]                           # the form number is in f[0], ref slug in f[4] and
      reftypeH[f[0]] = f[3]                                # the reference type in f[3]
   end
   ffa.each do |f|                                               # and populate bffS
      bffS << [f[0], f[3], f[4]]
      reftypeH[f[0]] = f[3]
   end

   w = btfS.to_a                                                  #diagnostic
   z = bffS.to_a   #diagnostic
   w.sort!
   z.sort!
   $diagnosticfile.print "Basic True Forms \n #{w}\nBasic False Forms \n #{z} \n"    # diagnostic (originally
                                                                             # diagnostic but the file has proven to be pretty useful)

   # Now we have to populate the set tfS of all forms true in the model and ffS of all forms false in #
   # the model.  A form is true if it's implied by something in btfS and false if it implies something   #
   # in bffS
   tfS = Set.new
   ffS = Set.new
#   tfS = btfS
#   ffS = bffS
   tfSnos = Set.new       # Since tfS and ffS have arrays as elements we need sets which contain
   ffSnos = Set.new       # just the form numbers of the true and false forms
   btfS.each do |a|
     tfS << a
     tfSnos << a[0]
   end
   bffS.each do |b|
     ffS << b
     ffSnos << b[0]
   end
   btfS.each do |f1|
      (0..numberOfForms -1).each do |f2|
         if ((b1[f1[0]][f2] == 1 || b1[f1[0]][f2] == 2) && !(tfSnos.include?(f2)))  # don't want to overwrite
            tfS << [f2, "follows from implications","#{f1[0]} is true"]
            tfSnos << f2
         end
      end
   end
   bffS.each do |f1|
      (0..numberOfForms-1).each do |f2|
         if ((b1[f2][f1[0]] ==1 || b1[f2][f1[0]] == 2) && !(ffSnos.include?(f2)))
            ffS << [f2,"follows from implications","#{f1[0]} is false"]
            ffSnos << f2
         end       
      end
   end
   w = tfS.to_a                                                                          # diagnostic
   z = ffS.to_a                                                                            # diagnostic
   w.sort!                                                                                    # diagnostic
   z.sort!                                                                                     # diagnostic
   $diagnosticfile.print "All True Forms \n #{w} \nAll False Forms \n #{z} \n\n"    # diagnostic (no longer
                                                                                                   # diagnostic)
   w.each do |form|
     $form_model.print "  #{form[0]} #{modelid}  #{modelprefix}#{modelnumber}#{modelsuffix}  T  #{form[1]} #{form[2]} \n"
   end
   z.each do |form|
     $form_model.print "  #{form[0]} #{modelid}  #{modelprefix}#{modelnumber}#{modelsuffix}  F  #{form[1]} #{form[2]} \n" 
   end
   # Next update the matrix independ

   if modelprefix == "M"                                 # First we handle the Cohen models (prefix "M")
      tfS.each do |tf|                                           # for each true form (HR-no) (true in the model)
         ffS.each do |ff|                                        # and each false form
            if reftypeH[tf[0]] && reftypeH[ff[0]] &&  !reftypeH[tf[0]].match(/calculated/) && !reftypeH[ff[0]].match(/calculated/)
               self[tf[0]][ff[0]] = 3                                   # referenced positions get a non-implication code 3
            else
              self[tf[0]][ff[0]] = repby(self[tf[0]][ff[0]],4)    # otherwise use code 4 (if it's not already a 3)
            end
         end
      end
   end

   if modelprefix == "N"                                  # now the FM models where we have to worry about transfer
      ttfS = Set.new                                            # ttfS (transferable true forms for this model)
      tffS = Set.new                                            # transferable false forms for this model
      # every true form implied by a true and absolutely transferable form will be transferable for this model
      tfS.each do |f1|
         if $transferableS.include?(f1[0])
            tfS.each do |f2|
               if b1[f1[0]][f2[0]] == 1 || b1[f1[0]][f2[0]] == 2
                  ttfS << f2[0]
               end
            end
         end        
      end
      ffS.each do |f1|                                          
         # every false form which implies a false and absolutely negation transferable form is negation 
         # transferable for this model
         if $negationTransS.include?(f1[0])
            ffS.each do |f2|
               if b1[f2[0]][f1[0]] ==1 || b1[f2[0]][f1[0]] == 2
                  tffS << f2[0]
               end
            end
         end       
      end 

      w = ttfS.to_a                                             #diagnostic
       z = tffS.to_a                                              #diagnostic
      w.sort!                                                         #diagnostic
      z.sort!                                                           #diagnostic
      $diagnosticfile.print "Model Transferable Forms \n #{w} \n Model Negation Transferable Forms \n #{z} \n\n"  #diagnostic
                                                                           # line above no longer diagnostic      
     tfS.each do |tf|                                              # (still working on FM models) we update independ                       
        ffS.each do |ff|
           if ttfS.include?(tf[0]) &&tffS.include?(ff[0])
              self[tf[0]][ff[0]] = repby(self[tf[0]][ff[0]],4)
           else
              if reftypeH[tf[0]] && reftypeH[ff[0]] && !reftypeH[tf[0]].match(/calculated/) && !reftypeH[ff[0]].match(/calculated/)
                 self[tf[0]][ff[0]] = repby(self[tf[0]][ff[0]], 5)
              else
                 self[tf[0]][ff[0]] = repby(self[tf[0]][ff[0]], 6)
              end
           end
        end
     end
   end
end

####################### end independ.update ###############################


##################################################################
#                                                  End Methods                                                                                                # #                                                                                                                                                                          #
##################################################################

# Get the first and second line of potentialbiggie from the file pbText.csv with file handle pb.  Recall
# that the rows of pbText have the form
#   model_id # form_id # * # Form Number # reference_type # model_tex_name # FormNumber # form_statement # 
#   reference_slug # optional # true_or_false # trans # neg-trans
# with the symbol # as a column separator.


pbline = pb.gets                                                   # read the first line of "potentialbiggie" but don't do anythinng with it

pbline = pb.gets                                                         # read the second line
pblinearr = pbline.split("#")                                 # convert to an array by splitting at the #s
begin
   modelname = pblinearr[5]
   modelid = pblinearr[0]
   m = pblinearr[5].match(/cal\s*([MN])(\d+)(.*)/ )   # The model prefix (M or N), model number and model suffix are in
                                                                                   # pblinearr[5].
   modelprefix = m[1]
   modelnumber = m[2]
   modelsuffix = m[3]
   print "\n prefix #{modelprefix} \n number #{modelnumber} \n suffix #{modelsuffix} \n"  #diagnostic
   tfa.clear                                                                       # for the forms which are true in this model
   ffa.clear                                                                        # for the forms which are false in this model
   begin  
      ref = pblinearr[8]                                                 # this entry contains the reference
      if(!ref.match(/\s*note[-\s]\s*120/) and !ref.match(/\s*note[-\s]\s*2/))       # we want to skip lines with ref note-120 
                                                                                                                                           # or note-2
         torf = pblinearr[10]                                             # this entry contains "historically-true" or "historically false"
         if torf.match(/true/)
            tfa[tfa.length] = [pblinearr[3].to_i , pblinearr[0].to_i, pblinearr[1].to_i, pblinearr[4], pblinearr[8], pblinearr[9],\
                                            pblinearr[5], pblinearr[10], pblinearr[11], pblinearr[12]] 
         # add a row to tfa: [form no. (0), model id (1), form id (2),  ref type (3), ref slug (4), 
         #  optional (5), model name (6), t/f (7), transferable (8), neg. trans (9)]
         else
            ffa[ffa.length] = [pblinearr[3].to_i , pblinearr[0].to_i, pblinearr[1].to_i, pblinearr[4], pblinearr[8], pblinearr[9],\
                                            pblinearr[5], pblinearr[10], pblinearr[11], pblinearr[12]] 
                                                                                        #add to ffa
         end
      end                                                                         # end "if not note-120 or note-2
      if(! pbline = pb.gets)                                            # read another line
         break
      end                                                  
      pblinearr = pbline.split("#")                                 # convert to an array by splitting at the #s
   end until (modelid != pblinearr[0])                        # repeat this block until we've found the next model
  
   if modelprefix =="M"
      begin
         starttfalength = tfa.size                          # initialize starttfalength and
         startffalength = ffa.size                           # and startffalength
         tfa.note120check(b1,n120,modelid,modelname,ffa)                    # do the note 120 updating on tfa
         ffa.note120check(b1, n120,tfa, modelid,modelname)                    # do the note 120 updating on ffa 
      end until (starttfalength == tfa.size && startffalength == ffa.size)     # repeat if either array has been increased in size
   end
   if modelprefix == "N"
      begin
         starttfalength = tfa.size                              # do the same if the model prefix is "N" but include note 2 updating also
         startffalength = ffa.size
         tfa.note120check(b1,n120,modelid, modelname,ffa)
         tfa.note2check(b1,n2,modelid, modelname)
         ffa.note120check(b1,n120,tfa, modelid, modelname)
         ffa.note2check(b1,n2,tfa, modelid, modelname)
      end until (starttfalength == tfa.size && startffalength == ffa.size)     # repeat if either array has been increased in size
   end
   
   ####### add entries to the matrix independ ############

   $diagnosticfile.print "Model #{modelprefix}#{modelnumber}#{modelsuffix}  - Model_id #{modelid}\n\n"    # diagnostic
   independ.update(tfa,ffa,b1, modelid, modelprefix,modelnumber,modelsuffix)
#   print "#{independ[0]} \n\n"                                #diagnostic

end until(pb.eof?)                                                    # when we've finished reading potentialbiggie
pb.close
$diagnosticfile.close
$form_model.close
   ###### checking book1 (b1) against independ and printing ################

   ##### We want to make sure that no non-implication entry in b1 is better than the corresponding entry in independ ##
   ##### In other words if the b1 entry (b1ent) is 3, 4, 5 or 6 then the corresponding independ entry (indent) should     ##
   ##### be 3, 4, 5 or 6 and less than or equal to b1ent                                                                                                                      ##

(0..numberOfForms - 1).each do |hyp|
   (0..numberOfForms -1).each do |conc|
      b1ent = b1[hyp][conc]
      indent = independ[hyp][conc]
      if 3 <= b1ent && b1ent <= 6                                                # these are the conditions under which we check
         if indent == 0 || ((b1ent == 3 || b1ent == 4) && (indent != 3 && indent != 4))                       # we print a line if the book1 entry is better
            modfile.print "Problem:  the book1 entry at (#{hyp},#{conc}) is #{b1ent} but \n"
            modfile.print "   the indepent entry is #{indent}. \n\n"
         end
      end
   end
end

# and let's save a copy of the array independ, one row per line
matrixfile = File.new("independ", "w")
independ.each do |row|
   row.each do |code|
      matrixfile.print " #{code} "
   end
   matrixfile.print "\n"
end 
matrixfile.close 

######## Checking independ against rfb1 (as stored in the file rfb1.dat) and printing the results in rfb1_indCk.out) ####

rfb1 = File.open("Rfb1.dat")
rfb1_indCk = File.new("rfb1_indCk.out", "w")
rfb1.each_line do |rfline|
   rfline.chomp!
   m = rfline.match(/\s*(\d+)\s+(\d+)\s+\((\d)\) \s+(.*)/)
   rfhyp = m[1].to_i
   rfconc = m[2].to_i
   rfcode = m[3].to_i
   indepcode = independ[rfhyp][rfconc]                        
   if 3 <= rfcode && rfcode <= 6                                        # these are the non-implication codes
      if indepcode ==0 || ((rfcode == 3 || rfcode == 4) && (indepcode != 3 && indepcode != 4))
         rfb1_indCk.print " Problem at Position (#{rfhyp},#{rfconc}) \n rfb1 has \b"
        rfb1_indCk.print "code #{rfcode} but independ has #{indepcode}. \n"
         rfb1_indCk.print "#{m[4]} \n\n"
      end      
   end
end
rfb1.close
rfb1_indCk.close
      
   ################ end printing results ###############

   


modfile.close

