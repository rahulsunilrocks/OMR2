function templates = retrieveTemplates(est_note_diam)
% Find and return templates for quarter, whole, half notes
q_note = double(rgb2gray(imread('./templates/quarter_note.png')))./255;
templates.q_note = imresize(q_note,[est_note_diam,(size(q_note,2)/size(q_note,1))*est_note_diam]);
h_note = double(rgb2gray(imread('./templates/half_note.png')))./255;
templates.h_note = imresize(h_note,[est_note_diam,(size(h_note,2)/size(h_note,1))*est_note_diam]);
w_note = double(rgb2gray(imread('./templates/whole_note.png')))./255;
templates.w_note = imresize(w_note,[est_note_diam,(size(w_note,2)/size(w_note,1))*est_note_diam]);
end

